defmodule FrontmanServer.Tasks.TaskStore do
  @moduledoc """
  Persistence layer for tasks using ETS.

  Handles all storage operations. Can be swapped for a different
  storage backend (Postgres, etc.) without affecting the public API.
  """

  @table :tasks

  @doc """
  Inserts a task into storage.

  Returns `:ok` on success.
  """
  @spec insert(map()) :: :ok
  def insert(task) do
    :ets.insert(@table, {task.task_id, task})
    :ok
  end

  @doc """
  Gets a task by ID.

  Returns `{:ok, task}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(task_id) do
    case :ets.lookup(@table, task_id) do
      [{^task_id, task}] -> {:ok, task}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Updates a task by applying a function to it.

  Returns `{:ok, updated_task}` if successful, `{:error, :not_found}` if task doesn't exist.
  """
  @spec update(String.t(), (map() -> map())) :: {:ok, map()} | {:error, :not_found}
  def update(task_id, update_fn) do
    case get(task_id) do
      {:ok, task} ->
        updated_task = update_fn.(task)
        insert(updated_task)
        {:ok, updated_task}

      {:error, :not_found} = error ->
        error
    end
  end

  @doc """
  Checks if a task exists.

  Returns `true` if the task exists, `false` otherwise.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(task_id) do
    case :ets.lookup(@table, task_id) do
      [{^task_id, _}] -> true
      [] -> false
    end
  end

  @doc """
  Deletes a task from storage.

  Returns `:ok` regardless of whether the task existed.
  """
  @spec delete(String.t()) :: :ok
  def delete(task_id) do
    :ets.delete(@table, task_id)
    :ok
  end
end
