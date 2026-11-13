defmodule FrontmanServer.Tasks.Execution.GlobalStateTest do
  use FrontmanServer.ExecutionCase

  import Mox
  import Phoenix.ChannelTest
  import FrontmanServer.DataCase, only: [setup_sandbox: 1]

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2, extract_content_text: 1]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Skills
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Protocols
  alias FrontmanServer.Repo
  alias FrontmanServer.Skills
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools.MCP

  @moduletag billing: :active
  @endpoint FrontmanServerWeb.Endpoint
  @acp_message Protocols.ACP.event_acp_message()

  defp submit_user_message(scope, task_id, %{content: content, overrides: overrides}) do
    execution = execution_request_fixture(overrides)

    submit_user_message_and_run(scope, task_id, %{
      execution: execution,
      message: content,
      runtime: FrontmanServer.AgentRuntime
    })
  end

  defp turn_started_rows(task_id) do
    task_id
    |> InteractionSchema.for_task()
    |> InteractionSchema.of_type(:turn_started)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  defp setup_channel(%{scope: scope, task_id: task_id}) do
    {:ok, _reply, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("task:#{task_id}", %{})

    {:ok, socket: socket}
  end

  defp with_backend_tools(modules) do
    previous = Application.fetch_env!(:frontman_server, :backend_tools)
    Application.put_env(:frontman_server, :backend_tools, modules)
    on_exit(fn -> Application.put_env(:frontman_server, :backend_tools, previous) end)
  end

  defp provider_texts(messages, role) do
    for %{role: ^role, content: content} <- messages, do: extract_content_text(content)
  end

  defp assert_active_count(expected, attempts \\ 50)

  defp assert_active_count(expected, 0) do
    assert SwarmAi.active_count(FrontmanServer.AgentRuntime) == expected
  end

  defp assert_active_count(expected, attempts) do
    case SwarmAi.active_count(FrontmanServer.AgentRuntime) do
      ^expected ->
        :ok

      _count ->
        Process.sleep(10)
        assert_active_count(expected, attempts - 1)
    end
  end

  describe "skill discovery and loading" do
    setup [:setup_sandbox, :setup_user, :setup_task, :verify_on_exit!]

    setup %{scope: scope} do
      Repo.delete_all(Skills.Skill)
      %{skill: skill_fixture(scope)}
    end

    test "does not advertise or load skills when the tool is unavailable", %{
      task_id: task_id,
      scope: scope,
      skill: skill
    } do
      parent = self()

      assert [%{source: :backend, name: name}] = Skills.list(scope)
      qualified_name = "backend:#{name}"

      with_backend_tools(
        Application.fetch_env!(:frontman_server, :backend_tools)
        |> Enum.reject(&(&1.name() == "skill"))
      )

      call = tool_call("skill", %{"name" => qualified_name}, id: "unavailable_skill")

      expect(LLMProviderMock, :stream_text, fn _model, messages, opts ->
        send(parent, {:without_skill_tool, messages, Enum.map(opts[:tools], & &1.name)})
        ReqLLMResponses.response({:tool_calls, [call], "Trying unavailable skill"})
      end)

      expect_llm_responses(["Continued without the unavailable tool"])

      {:ok, _, 1} =
        submit_user_message(scope, task_id, %{
          content: user_content("Improve the hero"),
          overrides: []
        })

      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
      assert_receive {:without_skill_tool, messages, tools}
      refute "skill" in tools
      assert [system] = provider_texts(messages, :system)
      refute system =~ qualified_name
      refute system =~ skill.description
      refute system =~ skill.content
      {:ok, task} = Tasks.get_task_with_history(scope, task_id)

      assert [%Interaction.ToolResult{tool_call_id: "unavailable_skill", is_error: true}] =
               Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end
  end

  describe "interactive waits and serial recovery" do
    @tag :application_restart
    @tag billing: :pretrial
    test "application shutdown preserves approval and resumes the fifth turn with no allowance left",
         context do
      Process.flag(:trap_exit, true)
      Sandbox.mode(Repo, :auto)
      %{scope: scope} = setup_user(context)
      FrontmanServer.BillingFixtures.run_allowance_fixture(scope, 4)
      task_id = task_with_pubsub_fixture(scope, framework: "wordpress").id

      on_exit(fn ->
        try do
          {:ok, _} = Application.ensure_all_started(:frontman_server)

          Sandbox.unboxed_run(Repo, fn ->
            FrontmanServer.RestartResources.delete_jobs(scope, task_id)
            Repo.delete!(Scope.user(scope))
          end)
        after
          Sandbox.mode(Repo, :manual)
        end
      end)

      approval = tool_call("approval", %{}, id: "approval_serial")
      write = tool_call("write_file", %{}, id: "write_serial")

      tools =
        MCP.from_maps([
          %{
            "name" => "approval",
            "_meta" => %{"ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}}
          },
          %{"name" => "write_file"}
        ])

      parent = self()
      expect_llm_responses([{:tool_calls, [approval, write], "Approve first"}])

      expect(LLMProviderMock, :stream_text, fn model, messages, _opts ->
        send(parent, {:resumed_messages, model, messages})
        ReqLLMResponses.response("Recovered")
      end)

      {:ok, _, 1} =
        submit_user_message(scope, task_id, %{
          content: user_content("Do the change"),
          overrides: [mcp_tools: tools]
        })

      assert_receive_interaction(
        %Interaction.ToolCall{tool_name: "approval", execution_mode: :interactive},
        1
      )

      refute_receive {:interaction, %{data: %Interaction.ToolCall{tool_name: "write_file"}}}, 250
      {:ok, waiting} = Tasks.get_task_with_history(scope, task_id)
      refute Enum.any?(Tasks.interactions(waiting), &match?(%Interaction.ToolResult{}, &1))
      refute Enum.any?(Tasks.interactions(waiting), &match?(%Interaction.AgentPaused{}, &1))

      assert_active_count(0)
      assert SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert :ok = Application.stop(:frontman_server)
        end)

      refute log =~ "unknown registry"
      {:ok, _} = Application.ensure_all_started(:frontman_server)
      :ok = Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")

      assert_receive_interaction(
        %Interaction.ToolResult{tool_name: "write_file", is_error: true},
        1
      )

      refute_receive {:interaction, %{data: %Interaction.AgentError{}}}, 50
      {:ok, pending} = Tasks.get_task_with_history(scope, task_id)

      assert [%Interaction.ToolCall{tool_name: "approval"}] =
               Enum.filter(Tasks.interactions(pending), &match?(%Interaction.ToolCall{}, &1))

      assert {:ok, 1, [%Interaction.ToolCall{tool_name: "approval"}]} =
               Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)

      assert {:error, :billing_inactive} =
               Tasks.submit_user_message(
                 scope,
                 Map.merge(execution_request_fixture(), %{
                   task_id: task_id,
                   message_id: Ecto.UUID.generate(),
                   message: user_content("New turns require billing")
                 })
               )

      assert {:ok, _, _} =
               Tasks.resolve_tool_request(
                 scope,
                 task_id,
                 approval,
                 Protocols.MCP.tool_result_text("yes")
               )

      refute_running_eventually(task_id)
      assert_active_count(0)

      assert :ok =
               Tasks.resume_execution(
                 scope,
                 task_id,
                 %{
                   execution:
                     execution_request_fixture(
                       model: "missing:connection-model",
                       mcp_tools: tools
                     ),
                   runtime: FrontmanServer.AgentRuntime
                 }
               )

      assert_receive {:resumed_messages, %LLMDB.Model{id: "openai/gpt-5.5"}, messages}, 1_000
      results = Enum.filter(messages, &(&1.role == :tool))
      assert Enum.map(results, & &1.tool_call_id) == [write.id, approval.id]

      assert Enum.map(results, &extract_content_text(&1.content)) == [
               "Interrupted by restart",
               "yes"
             ]

      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
      assert Tasks.remaining_runs(scope) == 0
      assert length(turn_started_rows(task_id)) == 1
      refute_receive {:interaction, %{data: %Interaction.ToolCall{tool_name: "write_file"}}}, 50
    end
  end

  defmodule CrashTool do
    @moduledoc false
    @behaviour FrontmanServer.Tools.Backend
    def name, do: "crash_tool"
    def description, do: "always crashes"
    def access, do: :write
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 5_000
    def execute(_args, _ctx), do: raise("boom")
  end

  defmodule HangTool do
    @moduledoc false
    @behaviour FrontmanServer.Tools.Backend
    def name, do: "hang_tool"
    def description, do: "hangs forever"
    def access, do: :write
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 100
    def execute(_args, _ctx), do: Process.sleep(:infinity)
  end

  describe "backend failures — persistence and channel notification" do
    setup [:setup_sandbox, :setup_user, :setup_task, :setup_channel]

    for {failure, module} <- [{"crash", CrashTool}, {"timeout", HangTool}] do
      test "#{failure} persists one error result and pushes idle", %{
        task_id: task_id,
        scope: scope,
        socket: socket
      } do
        module = unquote(module)
        call = tool_call(module.name())
        with_backend_tools([module])
        expect_llm_responses([{:tool_calls, [call], "Calling tool"}, "Handled."])

        {:ok, _, 1} =
          submit_user_message(scope, task_id, %{
            content: user_content("Do a thing"),
            overrides: []
          })

        assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
        :sys.get_state(socket.channel_pid)

        assert_push(@acp_message, %{
          "jsonrpc" => "2.0",
          "method" => "session/update",
          "params" => %{
            "sessionId" => ^task_id,
            "update" => %{"sessionUpdate" => "state_update", "state" => "idle"}
          }
        })

        {:ok, task} = Tasks.get_task_with_history(scope, task_id)

        assert [%Interaction.ToolResult{is_error: true, tool_call_id: call_id}] =
                 Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

        assert call_id == call.id
      end
    end
  end
end
