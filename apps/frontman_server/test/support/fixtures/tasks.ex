defmodule FrontmanServer.Test.Fixtures.Tasks do
  @moduledoc """
  Reusable fixtures for task test setup.

  Provides helpers for creating tasks and subscribing to their PubSub topics,
  replacing the manual `Ecto.UUID.generate() + Tasks.create_task()` pattern.
  """

  alias FrontmanServer.Tasks

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

  @doc """
  Create a task and subscribe the calling process to its PubSub topic.

  Accepts the same options as `task_fixture/2`.
  """
  @spec task_with_pubsub_fixture(FrontmanServer.Accounts.Scope.t(), keyword()) :: String.t()
  def task_with_pubsub_fixture(scope, opts \\ []) do
    task_id = task_fixture(scope, opts)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))
    task_id
  end

  @doc """
  Build a user message content block.

      iex> user_content("Hello")
      [%{"type" => "text", "text" => "Hello"}]
  """
  @spec user_content(String.t()) :: [map()]
  def user_content(text), do: [%{"type" => "text", "text" => text}]
end
