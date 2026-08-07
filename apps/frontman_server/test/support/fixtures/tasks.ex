defmodule FrontmanServer.Test.Fixtures.Tasks do
  use Boundary,
    top_level?: true,
    check: [in: false, out: false]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  import Ecto.Query, only: [from: 2]

  alias FrontmanServer.Tasks.{
    Interaction,
    InteractionSchema,
    TaskSchema
  }

  @default_test_model "openrouter:openai/gpt-5.5"

  def task_fixture(scope, opts \\ []) do
    framework = Keyword.get(opts, :framework, "nextjs")
    task_id = Keyword.get(opts, :task_id, Ecto.UUID.generate())
    {:ok, %TaskSchema{id: ^task_id} = task} = Tasks.create_task(scope, task_id, framework)
    task
  end

  def task_with_active_run_fixture(scope, opts \\ []) do
    task = task_fixture(scope, opts)
    start_turn_fixture(scope, task.id)
    task
  end

  def execution_request_fixture(overrides \\ []) do
    %{
      model: @default_test_model,
      agent_id: "test-frontman",
      project_traits: [],
      mcp_tools: []
    }
    |> Map.merge(Map.new(overrides))
  end

  def start_turn_fixture(
        scope,
        task_id,
        content_blocks \\ user_content("test turn"),
        model \\ @default_test_model
      ) do
    {:ok, _message} = user_message_fixture(scope, task_id, content_blocks, model)
    latest_turn_number(task_id)
  end

  def persist_tool_call_fixture(scope, task_id, turn_number, %Interaction.ToolCall{} = tool_call) do
    swarm_tool_call = %SwarmAi.ToolCall{
      id: tool_call.tool_call_id,
      name: tool_call.tool_name,
      arguments: Jason.encode!(tool_call.arguments)
    }

    Tasks.request_client_tool(scope, task_id, turn_number, swarm_tool_call)
  end

  def user_message_fixture(scope, task_id, content_blocks, model \\ @default_test_model) do
    task = task_schema!(scope, task_id)
    {:ok, attrs} = Interaction.UserMessage.attrs(content_blocks, model, "test-frontman")

    with {:ok, row} <-
           InteractionSchema.create_changeset(task.id, :user_message, attrs, nil)
           |> Repo.insert(),
         {:ok, _turn_started} <-
           InteractionSchema.create_changeset(
             task.id,
             :turn_started,
             %{
               id: Ecto.UUID.generate(),
               timestamp: Interaction.now(),
               agent_id: "test-frontman",
               user_message_ids: [row.id]
             },
             next_turn_number(task_id)
           )
           |> Repo.insert() do
      {:ok, row.data}
    end
  end

  defp task_schema!(scope, task_id) do
    user_id = Accounts.scope_user_id(scope)

    TaskSchema
    |> TaskSchema.by_id(task_id)
    |> TaskSchema.for_user(user_id)
    |> Repo.one!()
  end

  defp next_turn_number(task_id) do
    (max_turn_number(task_id) || 0) + 1
  end

  defp max_turn_number(task_id) do
    from(i in InteractionSchema.for_task(task_id), select: max(i.turn_number))
    |> Repo.one()
  end

  def task_with_pubsub_fixture(scope, opts \\ []) do
    task = task_fixture(scope, opts)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task.id))
    task
  end

  def task_topic(task_id), do: "task:#{task_id}"

  def user_content(text), do: [%{"type" => "text", "text" => text}]

  def latest_turn_number(task_id) do
    max_turn_number(task_id) || raise "No turn_number found for task #{task_id}"
  end
end
