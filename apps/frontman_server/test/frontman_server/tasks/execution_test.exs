defmodule FrontmanServer.Tasks.ExecutionIntegrationTest do
  @moduledoc """
  Integration tests for task execution flow.

  Tests the full lifecycle: cancel, tool result routing, consecutive messages,
  and terminal events through the channel layer. These exercise the Tasks
  facade, SwarmAi loop dispatch, and TaskChannel together.
  """
  use FrontmanServer.ExecutionCase
  use Oban.Testing, repo: FrontmanServer.Repo

  import Mox
  import Phoenix.ChannelTest

  import FrontmanServer.InteractionCase.Helpers,
    only: [
      annotation_block: 6,
      current_page_block: 2,
      extract_content_text: 1,
      agent_paused: 2,
      assert_receive_interaction: 2,
      interaction_row: 2,
      screenshot_block: 3,
      text_block: 1
    ]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  import FrontmanServer.Test.Fixtures.Tools,
    only: [question_args: 0, question_mcp_tool_defs: 0, todo_args: 0]

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools.MCP
  alias FrontmanServer.Workers.GenerateTitle
  alias ReqLLM.Error.API.Request

  @endpoint FrontmanServerWeb.Endpoint
  @acp_message AgentClientProtocol.event_acp_message()

  defp short_timeout_question_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        timeout_ms: 200,
        on_timeout: :pause_agent
      }
    ]
  end

  defp error_timeout_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        timeout_ms: 100,
        on_timeout: :error
      }
    ]
  end

  defp submit_user_message(scope, task_id, content, overrides \\ []) do
    execution = execution_request_fixture(overrides)

    case Tasks.submit_user_message(
           scope,
           Map.merge(execution, %{task_id: task_id, message: content})
         ) do
      {:ok, interaction} ->
        case Tasks.run_next_turn(scope, task_id, execution) do
          result when result in [:ok, :already_running] ->
            {:ok, interaction, latest_turn_number_or_nil(task_id)}

          result ->
            result
        end

      result ->
        result
    end
  end

  defp latest_turn_number_or_nil(task_id) do
    case Repo.aggregate(InteractionSchema.for_task(task_id), :max, :turn_number) do
      nil -> nil
      turn_number -> turn_number
    end
  end

  defp setup_sandbox(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    :ok
  end

  defp setup_user(_context) do
    scope = user_scope_fixture()
    {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")
    {:ok, scope: scope}
  end

  defp setup_task(%{scope: scope}) do
    {:ok, task_id: task_with_pubsub_fixture(scope).id}
  end

  defp setup_task_only(%{scope: scope}) do
    {:ok, task_id: task_fixture(scope).id}
  end

  defp setup_channel(%{scope: scope, task_id: task_id}) do
    {:ok, _reply, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("task:#{task_id}", %{})

    {:ok, socket: socket}
  end

  defp refute_running_eventually(task_id, attempts \\ 50)

  defp refute_running_eventually(task_id, attempts) when attempts > 0 do
    case SwarmAi.running?(FrontmanServer.AgentRuntime, task_id) do
      false ->
        :ok

      true ->
        Process.sleep(10)
        refute_running_eventually(task_id, attempts - 1)
    end
  end

  defp refute_running_eventually(task_id, 0) do
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task_id),
           "Agent should not be running after completion"
  end

  defp with_backend_tools(modules) do
    previous = Application.fetch_env!(:frontman_server, :backend_tools)
    Application.put_env(:frontman_server, :backend_tools, modules)
    on_exit(fn -> Application.put_env(:frontman_server, :backend_tools, previous) end)
  end

  describe "cancel_execution/2 (end-to-end)" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "cancel dispatches cancelled event via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([{:delay, "slow", 5000}])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Hello"))

      Process.sleep(100)
      assert SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)

      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive_interaction(%Interaction.AgentError{kind: "cancelled"}, _turn_number)

      refute_running_eventually(task_id)
    end

    test "cancel respects task ownership", %{task_id: task_id} do
      other_scope = user_scope_fixture()

      assert Tasks.cancel_execution(other_scope, task_id) == {:error, :not_found}
    end
  end

  describe "conversation lifecycle" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "runs next accepted user message as a turn", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses(["Response"])

      {:ok, _} =
        Tasks.submit_user_message(scope, %{
          task_id: task_id,
          message: user_content("Hello"),
          model: "openrouter:openai/gpt-5.5"
        })

      assert :ok = Tasks.run_next_turn(scope, task_id, execution_request_fixture())

      assert_receive_interaction(%Interaction.TurnStarted{}, 1)
      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
      refute_running_eventually(task_id)
    end

    test "accepts follow-up while running and drains it next", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([{:delay, "First response", 500}, "Second response"])

      {:ok, _, 1} = submit_user_message(scope, task_id, user_content("First message"))

      Process.sleep(100)

      assert {:ok, %Interaction.UserMessage{}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task_id,
                 message: user_content("Queued follow-up"),
                 model: "openrouter:openai/gpt-5.5"
               })

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      refute_running_eventually(task_id)

      assert :ok = Tasks.run_next_turn(scope, task_id, execution_request_fixture())

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      refute_running_eventually(task_id)

      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_responses =
        Enum.filter(task.interactions, &match?(%Interaction.AgentResponse{}, &1))

      assert length(agent_responses) == 2,
             "Expected 2 agent responses, got #{length(agent_responses)}"

      assert task.interactions |> Enum.filter(&match?(%Interaction.UserMessage{}, &1)) |> length() ==
               2
    end

    test "returns invalid content block errors instead of raising", %{
      task_id: task_id,
      scope: scope
    } do
      assert {:error,
              {:invalid_content_block, "text content block must include non-empty string text"}} =
               submit_user_message(scope, task_id, [%{"type" => "text", "text" => ""}])
    end

    test "uses resource context for attachment-only first turn title text", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses(["Response"])

      {:ok, _, 1} =
        submit_user_message(scope, task_id, [
          current_page_block("https://example.com/app", %{
            "viewport_width" => 390,
            "viewport_height" => 844
          })
        ])

      title_job =
        all_enqueued(worker: GenerateTitle)
        |> Enum.find(&(&1.args["task_id"] == task_id))

      assert title_job.args["user_prompt_text"] =~ "https://example.com/app"

      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
    end

    test "startup failure persists terminal error on the same turn" do
      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope).id

      {:ok, _, 1} =
        submit_user_message(scope, task_id, user_content("Hello"), model: "missing:test")

      assert_receive_interaction(%Interaction.AgentError{category: "auth"}, 1)

      assert %InteractionSchema{turn_number: 1, data: %Interaction.AgentError{category: "auth"}} =
               Repo.get_by!(InteractionSchema,
                 task_id: task_id,
                 type: :agent_error
               )

      assert {:ok, :no_active_run} = Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end

    test "submits browser context prompt through production recording path" do
      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope).id

      content_blocks = [
        text_block("Change headline"),
        current_page_block("http://localhost:4321/", %{
          "viewport_width" => 1316,
          "viewport_height" => 1269,
          "device_pixel_ratio" => 2,
          "title" => "Frontman: Visual AI Frontend Editing",
          "color_scheme" => "dark",
          "scroll_y" => 0
        }),
        annotation_block("ann-hero", "H1", "apps/marketing/src/components/Hero.astro", 65, 36,
          comment: "change this text to Danni",
          component_name: "Hero",
          component_props: %{},
          css_classes: "hero-section__title",
          nearby_text: "See it. Say it. Ship it.",
          bounding_box: %{"x" => 373.8, "y" => 152.0, "width" => 553.4, "height" => 62.0},
          parent: %{
            "file" => "apps/marketing/src/layouts/Layout.astro",
            "line" => 56,
            "column" => 51,
            "component_name" => "Header",
            "component_props" => %{"title" => "Frontman"}
          }
        ),
        screenshot_block("ann-hero", Base.encode64("screenshot"), "image/jpeg")
      ]

      {:ok, returned, 1} =
        submit_user_message(scope, task_id, content_blocks, model: "missing:test")

      assert %Interaction.CurrentPage{url: "http://localhost:4321/"} = returned.current_page

      assert [%Interaction.Annotation{parent: %Interaction.ParentLocation{}}] =
               returned.annotations

      assert_receive_interaction(%Interaction.UserMessage{} = broadcast_message, nil)

      assert [%Interaction.Annotation{screenshot: %Interaction.Screenshot{}}] =
               broadcast_message.annotations

      assert_receive_interaction(%Interaction.AgentError{category: "auth"}, 1)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.UserMessage{} = persisted_message | _] = task.interactions

      assert %Interaction.CurrentPage{title: "Frontman: Visual AI Frontend Editing"} =
               persisted_message.current_page

      assert [%Interaction.Annotation{bounding_box: %Interaction.BoundingBox{}}] =
               persisted_message.annotations

      [swarm_message] = Interaction.to_swarm_messages([persisted_message])
      text = extract_content_text(swarm_message.content)

      assert text =~ "[Current Page Context]"
      assert text =~ "[Annotated Elements]"
      assert text =~ "apps/marketing/src/components/Hero.astro"
      assert Enum.any?(swarm_message.content, &match?(%{type: :image}, &1))
    end

    test "conversation with tool calls supports follow-up messages", %{
      task_id: task_id,
      scope: scope
    } do
      tc = tool_call("todo_write")

      expect_llm_responses([
        {:tool_calls, [tc], "Here are your todos"},
        "Here are your todos",
        "Based on the previous results..."
      ])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Show todos"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Summarize"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)
      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert length(completions) == 2
    end

    test "rejects retrying an older turn", %{
      task_id: task_id,
      scope: scope
    } do
      {:ok, _message} = user_message_fixture(scope, task_id, user_content("turn one"))
      turn_one = latest_turn_number(task_id)

      {:ok, error} =
        Tasks.record_agent_run_result(scope, task_id, turn_one, {:failed, "Rate limited"})

      {:ok, _message} = user_message_fixture(scope, task_id, user_content("turn two"))
      turn_two = latest_turn_number(task_id)
      {:ok, _done} = Tasks.record_agent_run_result(scope, task_id, turn_two, :completed)

      assert {:error, :stale_turn} =
               Tasks.retry_execution(
                 scope,
                 task_id,
                 error.id,
                 execution_request_fixture()
               )

      {:ok, task} = Tasks.get_task(scope, task_id)

      refute Enum.any?(task.interactions, &match?(%Interaction.AgentRetry{}, &1))
    end
  end

  describe "append-only prompt building" do
    setup [:setup_sandbox, :setup_user, :setup_task_only]

    test "excludes accepted messages not claimed by the started turn", %{
      task_id: task_id,
      scope: scope
    } do
      parent = self()
      task = task_schema!(task_id)
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      start_turn_fixture(scope, task_id, user_content("included"))

      insert_accepted_user_message!(task, "queued for next turn")

      expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
        send(parent, {:provider_messages, messages})
        ReqLLMResponses.response("done")
      end)

      assert :ok = Tasks.resume_execution(scope, task_id, execution_request_fixture())

      assert_receive {:provider_messages, messages}, 1_000
      assert [user_text] = provider_user_texts(messages)
      assert user_text =~ "included"
      refute user_text =~ "queued for next turn"
      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
    end

    test "includes every user message claimed by the started turn in order", %{
      task_id: task_id,
      scope: scope
    } do
      parent = self()
      task = task_schema!(task_id)
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      insert_accepted_user_message!(task, "first")
      insert_accepted_user_message!(task, "second")
      insert_turn_started_for_messages!(task_id, 1)

      expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
        send(parent, {:provider_messages, messages})
        ReqLLMResponses.response("done")
      end)

      assert :ok = Tasks.resume_execution(scope, task_id, execution_request_fixture())

      assert_receive {:provider_messages, messages}, 1_000
      assert provider_user_texts(messages) == ["first", "second"]
      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
    end
  end

  describe "interactive tool (question) blocking" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "question tool blocks until result arrives, then agent completes", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_question_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      expect_llm_responses([{:tool_calls, [question_tc], "Great choice!"}, "Great choice!"])

      {:ok, _, _} =
        submit_user_message(scope, task_id, user_content("Ask me"),
          mcp_tools: question_mcp_tool_defs()
        )

      Process.sleep(200)
      assert SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)

      {:ok, _interaction, _status} =
        Tasks.resolve_tool_request(
          scope,
          task_id,
          %{id: question_tc_id, name: "question"},
          ModelContextProtocol.tool_result_json(%{"answers" => [%{"answer" => "A"}]}),
          false
        )

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_name: "question"} -> true
          _ -> false
        end)

      assert [_ | _] = tool_results

      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert [_ | _] = completions
    end
  end

  describe "title generation enqueue" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "first message enqueues a title generation job", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses(["Response"])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Build me a login page"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      assert_enqueued(worker: GenerateTitle, args: %{task_id: task_id})
    end

    test "second message does not enqueue an additional title generation job", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses(["First response", "Second response"])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Build me a login page"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Now add a signup form"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      enqueued = all_enqueued(worker: GenerateTitle)

      title_jobs_for_task =
        Enum.filter(enqueued, fn job -> job.args["task_id"] == task_id end)

      assert length(title_jobs_for_task) == 1
    end
  end

  describe "interactive tool timeout — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted in DB when question tool times out", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_timeout_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      expect_llm_responses([{:tool_calls, [question_tc], "done"}])

      {:ok, _, _} =
        submit_user_message(scope, task_id, user_content("Ask me"),
          mcp_tools: short_timeout_question_mcp_tool_defs()
        )

      assert_receive_interaction(%Interaction.AgentPaused{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert length(tool_results) == 1,
             "Expected exactly 1 ToolResult for the timed-out ToolCall, got #{length(tool_results)} — double-persist bug"

      [tool_result] = tool_results
      %{"content" => [%{"text" => result_text}], "isError" => true} = tool_result.result
      assert tool_result.is_error == true

      assert result_text =~ "on_timeout: :pause_agent",
             "Expected ToolResult message to come from loop pause handling (includes policy name), got: #{inspect(tool_result.result)}"
    end
  end

  describe "MCP tool timeout with on_timeout: :error" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted in DB when MCP tool times out (on_timeout: :error)", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_error_timeout_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      expect_llm_responses([
        {:tool_calls, [question_tc], "Calling question"},
        "Understood, the tool timed out."
      ])

      {:ok, _, _} =
        submit_user_message(scope, task_id, user_content("Ask me"),
          mcp_tools: error_timeout_mcp_tool_defs()
        )

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_call_interaction =
        Enum.find(task.interactions, fn
          %Interaction.ToolCall{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert tool_call_interaction != nil,
             "Expected a ToolCall interaction to be persisted"

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the timed-out ToolCall — " <>
               "every persisted ToolCall must have a matching ToolResult"

      assert tool_result.is_error == true
    end
  end

  describe "interactive tool timeout — client notification" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "session/update is pushed to client when agent pauses", %{
      task_id: task_id,
      socket: socket
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        {:interaction, interaction_row(agent_paused("question", 120_000), 1)}
      )

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "requires_action"}
        }
      })
    end
  end

  describe "backend tool execution — Tasks facade level" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "todo_write executes successfully — not rejected as Unknown tool", %{
      task_id: task_id,
      scope: scope
    } do
      ref =
        :telemetry_test.attach_event_handlers(self(), [[:swarm_ai, :tool, :execute, :stop]])

      on_exit(fn -> :telemetry.detach(ref) end)

      tc_id = "tc_todo_#{System.unique_integer([:positive])}"
      todo_tc = tool_call("todo_write", todo_args(), id: tc_id)
      expect_llm_responses([{:tool_calls, [todo_tc], "Writing todos"}, "Todos written."])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Write todos"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      # The telemetry stop event fires only after the backend tool actually runs.
      # The missing tool_defs regression skipped execution before producing this event.
      assert_receive {[:swarm_ai, :tool, :execute, :stop], ^ref, _measurements, meta}
      assert meta.tool_name == "todo_write"

      assert meta.is_error == false,
             "todo_write returned an error — " <>
               "backend tool was rejected as unavailable. " <>
               "Got: #{inspect(meta.output)}"
    end
  end

  describe "backend tool execution — channel level" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "todo_write executes through the full channel → executor pipeline", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      ref =
        :telemetry_test.attach_event_handlers(self(), [[:swarm_ai, :tool, :execute, :stop]])

      on_exit(fn -> :telemetry.detach(ref) end)

      tc_id = "tc_todo_ch_#{System.unique_integer([:positive])}"
      todo_tc = tool_call("todo_write", todo_args(), id: tc_id)
      expect_llm_responses([{:tool_calls, [todo_tc], "Writing todos"}, "Todos written."])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Write todos"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "idle"}
        }
      })

      assert_receive {[:swarm_ai, :tool, :execute, :stop], ^ref, _measurements, meta}
      assert meta.tool_name == "todo_write"

      assert meta.is_error == false,
             "todo_write returned an error through the channel pipeline — " <>
               "backend tool was rejected as unavailable. " <>
               "Got: #{inspect(meta.output)}"
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
    def on_timeout, do: :error
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
    def on_timeout, do: :error
    def execute(_args, _ctx), do: Process.sleep(:infinity)
  end

  describe "backend tool crash — channel notification" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "session/update idle state is pushed when backend tool raises", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      tc_id = "tc_crash_ch_#{System.unique_integer([:positive])}"
      crash_tc = tool_call("crash_tool", %{}, id: tc_id)
      with_backend_tools([CrashTool])
      expect_llm_responses([{:tool_calls, [crash_tc], "Calling crash tool"}, "Handled."])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Do a thing"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "idle"}
        }
      })
    end
  end

  describe "backend tool timeout (ParallelExecutor) — channel notification" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "session/update idle state is pushed when ParallelExecutor deadline fires", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      tc_id = "tc_hang_ch_#{System.unique_integer([:positive])}"
      hang_tc = tool_call("hang_tool", %{}, id: tc_id)
      with_backend_tools([HangTool])
      expect_llm_responses([{:tool_calls, [hang_tc], "Calling hang tool"}, "Handled."])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Do a thing"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "idle"}
        }
      })
    end
  end

  describe "supervisor-initiated termination (end-to-end)" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "terminated event persists error", %{
      task_id: task_id,
      scope: scope
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      expect_llm_responses([{:exit, :shutdown}])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Hello"))

      assert_receive_interaction(%Interaction.AgentError{kind: "terminated"}, _turn_number)

      # Verify DB persistence
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "terminated"
      assert agent_error.error == "Terminated by supervisor"
    end
  end

  describe "crashed agent (end-to-end)" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "crashed event persists error and pushes error update to client",
         %{
           task_id: task_id,
           scope: scope,
           socket: socket
         } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      expect_llm_responses([{:raise, "agent boom"}])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Hello"))

      assert_receive_interaction(%Interaction.AgentError{kind: "crashed"}, _turn_number)

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "unknown"
          }
        }
      })

      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "crashed"
      assert agent_error.error =~ "agent boom"
    end
  end

  describe "failed agent (end-to-end)" do
    setup [
      :setup_sandbox,
      :setup_user,
      :setup_task_only,
      :setup_channel
    ]

    test "failed event persists classified error and pushes error update to client",
         %{
           task_id: task_id,
           scope: scope,
           socket: socket
         } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      expect_llm_responses([{:error, :llm_error}])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Hello"))

      assert_receive_interaction(%Interaction.AgentError{kind: "failed"}, _turn_number)

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "unknown"
          }
        }
      })

      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "failed"
      assert agent_error.retryable == false
      assert agent_error.category == "unknown"
    end

    @tag :capture_log
    test "retryable provider failures retry only after channel timer fires", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      attempts = :counters.new(1, [])

      expect(LLMProviderMock, :stream_text, 2, fn
        _model, _messages, opts ->
          provider_attempts = if Keyword.get(opts, :max_retries, 2) == 0, do: 1, else: 2
          :counters.add(attempts, 1, provider_attempts)

          case :counters.get(attempts, 1) do
            1 ->
              {:error, Request.exception(status: 429, reason: "rate limited")}

            count when count > 1 ->
              ReqLLMResponses.response("Recovered")
          end
      end)

      {:ok, _, 1} = submit_user_message(scope, task_id, user_content("Hello"))

      assert_receive_interaction(
        %Interaction.AgentError{retryable: true, category: "rate_limit"},
        1
      )

      :sys.get_state(socket.channel_pid)

      assert :counters.get(attempts, 1) == 1

      assert_push(@acp_message, %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "rate_limit",
            "attempt" => 1,
            "retryAt" => _
          }
        }
      })

      %{assigns: %{retry_state: retry_state}} = :sys.get_state(socket.channel_pid)
      send(socket.channel_pid, {:fire_retry, retry_state.timer_token})

      assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
      assert :counters.get(attempts, 1) == 2
    end
  end

  describe "backend tool crash — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted when backend tool raises", %{
      task_id: task_id,
      scope: scope
    } do
      tc_id = "tc_crash_#{System.unique_integer([:positive])}"
      crash_tc = tool_call("crash_tool", %{}, id: tc_id)
      with_backend_tools([CrashTool])

      expect_llm_responses([
        {:tool_calls, [crash_tc], "Calling crash tool"},
        "Handled the crash."
      ])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Do a thing"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the crashed backend tool — " <>
               "every dispatched ToolCall must have a matching ToolResult in DB"

      assert tool_result.is_error == true
    end
  end

  describe "backend tool timeout (ParallelExecutor) — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted when ParallelExecutor deadline fires before tool returns", %{
      task_id: task_id,
      scope: scope
    } do
      tc_id = "tc_hang_#{System.unique_integer([:positive])}"
      hang_tc = tool_call("hang_tool", %{}, id: tc_id)
      with_backend_tools([HangTool])

      expect_llm_responses([
        {:tool_calls, [hang_tc], "Calling hang tool"},
        "Handled the timeout."
      ])

      {:ok, _, _} = submit_user_message(scope, task_id, user_content("Do a thing"))

      assert_receive_interaction(%Interaction.AgentCompleted{}, _turn_number)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the timed-out backend tool — " <>
               "ParallelExecutor fires before await_backend_tool, bypassing persistence"

      assert tool_result.is_error == true
    end
  end

  defp task_schema!(task_id), do: Repo.get!(FrontmanServer.Tasks.TaskSchema, task_id)

  defp insert_accepted_user_message!(task, text) do
    {:ok, attrs} = Interaction.UserMessage.attrs(user_content(text), "openrouter:openai/gpt-5.5")

    InteractionSchema.create_changeset(task.id, :user_message, attrs, nil)
    |> Repo.insert!()
  end

  defp insert_turn_started_for_messages!(task_id, turn_number) do
    user_message_ids =
      InteractionSchema
      |> InteractionSchema.for_task(task_id)
      |> InteractionSchema.of_type(:user_message)
      |> InteractionSchema.ordered()
      |> Repo.all()
      |> Enum.map(& &1.id)

    InteractionSchema.create_changeset(
      task_id,
      :turn_started,
      %{
        id: Ecto.UUID.generate(),
        timestamp: Interaction.now(),
        user_message_ids: user_message_ids
      },
      turn_number
    )
    |> Repo.insert!()
  end

  defp provider_user_texts(messages) do
    messages
    |> Enum.filter(&match?(%{role: :user}, &1))
    |> Enum.map(&extract_content_text(&1.content))
  end
end
