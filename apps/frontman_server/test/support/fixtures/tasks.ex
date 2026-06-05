defmodule FrontmanServer.Test.Fixtures.Tasks do
  @moduledoc """
  Reusable fixtures for task test setup.

  Provides helpers for creating tasks and subscribing to their PubSub topics,
  replacing the manual `Ecto.UUID.generate() + Tasks.create_task()` pattern.
  """

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

  @doc """
  Create a task and return its ID.

  ## Options

    * `:framework` - framework string, defaults to `"nextjs"`
    * `:task_id` - explicit task ID, defaults to `Ecto.UUID.generate()`
  """
  @spec task_fixture(FrontmanServer.Accounts.Scope.t(), keyword()) :: String.t()
  def task_fixture(scope, opts \\ []) do
    framework = Keyword.get(opts, :framework, "nextjs")
    task_id = Keyword.get(opts, :task_id, Ecto.UUID.generate())
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)
    task_id
  end

  def task_with_active_run_fixture(scope, opts \\ []) do
    task_id = task_fixture(scope, opts)
    start_turn_fixture(scope, task_id)
    task_id
  end

  @doc "Build a production-shaped execution request for task execution tests."
  def execution_request_fixture(overrides \\ []) do
    %{
      tools: [],
      model: nil,
      project_traits: [],
      backend_tool_modules: FrontmanServer.Tools.backend_tool_modules(),
      mcp_tool_defs: []
    }
    |> Map.merge(Map.new(overrides))
  end

  @doc "Persist a user message and return its turn number."
  @spec start_turn_fixture(FrontmanServer.Accounts.Scope.t(), String.t(), list()) :: pos_integer()
  def start_turn_fixture(scope, task_id, content_blocks \\ user_content("test turn")) do
    {:ok, _message} = user_message_fixture(scope, task_id, content_blocks)
    latest_turn_number(task_id)
  end

  @doc "Persist a domain tool call in a specific turn."
  @spec persist_tool_call_fixture(
          FrontmanServer.Accounts.Scope.t(),
          String.t(),
          pos_integer(),
          Interaction.ToolCall.t()
        ) ::
          {:ok, Interaction.ToolCall.t()}
          | {:error, :not_found | {:invalid_tool_arguments, String.t()}}
  def persist_tool_call_fixture(scope, task_id, turn_number, %Interaction.ToolCall{} = tool_call) do
    swarm_tool_call = %SwarmAi.ToolCall{
      id: tool_call.tool_call_id,
      name: tool_call.tool_name,
      arguments: Jason.encode!(tool_call.arguments)
    }

    Tasks.request_client_tool(scope, task_id, turn_number, swarm_tool_call)
  end

  @doc """
  Persist a user message for tests without invoking the production execution API.
  """
  @spec user_message_fixture(FrontmanServer.Accounts.Scope.t(), String.t(), list()) ::
          {:ok, Interaction.UserMessage.t()} | {:error, Ecto.Changeset.t()}
  def user_message_fixture(scope, task_id, content_blocks) do
    task = task_schema!(scope, task_id)
    interaction = Interaction.UserMessage.new(content_blocks)

    case InteractionSchema.create_changeset(task, interaction, next_turn_number(task_id))
         |> Repo.insert() do
      {:ok, _schema} -> {:ok, interaction}
      error -> error
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

  @doc """
  Create a task and subscribe the calling process to its PubSub topic.

  Accepts the same options as `task_fixture/2`.
  """
  @spec task_with_pubsub_fixture(FrontmanServer.Accounts.Scope.t(), keyword()) :: String.t()
  def task_with_pubsub_fixture(scope, opts \\ []) do
    task_id = task_fixture(scope, opts)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))
    task_id
  end

  @doc "Returns the task PubSub topic used by task channels."
  @spec task_topic(String.t()) :: String.t()
  def task_topic(task_id), do: "task:#{task_id}"

  @doc """
  Build a user message content block.

      iex> user_content("Hello")
      [%{"type" => "text", "text" => "Hello"}]
  """
  @spec user_content(String.t()) :: [map()]
  def user_content(text), do: [%{"type" => "text", "text" => text}]

  @doc "Returns the latest non-null turn number for a task."
  @spec latest_turn_number(String.t()) :: pos_integer()
  def latest_turn_number(task_id) do
    max_turn_number(task_id) || raise "No turn_number found for task #{task_id}"
  end
end
