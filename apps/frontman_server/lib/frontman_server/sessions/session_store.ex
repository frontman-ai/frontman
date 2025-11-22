defmodule FrontmanServer.Sessions.SessionStore do
  @moduledoc """
  In-memory persistence for sessions using ETS.

  Similar to TaskStore pattern. Can be replaced with DB later.
  """

  @table :sessions

  @doc """
  Inserts a session into storage.
  """
  @spec insert(FrontmanServer.Sessions.Session.t()) :: :ok
  def insert(session) do
    :ets.insert(@table, {session.session_id, session})
    :ok
  end

  @doc """
  Gets a session by ID.
  """
  @spec get(String.t()) ::
          {:ok, FrontmanServer.Sessions.Session.t()} | {:error, :not_found}
  def get(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, session}] -> {:ok, session}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Updates a session.
  """
  @spec update(
          String.t(),
          (FrontmanServer.Sessions.Session.t() -> FrontmanServer.Sessions.Session.t())
        ) ::
          {:ok, FrontmanServer.Sessions.Session.t()} | {:error, :not_found}
  def update(session_id, update_fn) do
    case get(session_id) do
      {:ok, session} ->
        updated = update_fn.(session)
        insert(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Checks if session exists.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, _}] -> true
      [] -> false
    end
  end

  @doc """
  Deletes a session.
  """
  @spec delete(String.t()) :: :ok
  def delete(session_id) do
    :ets.delete(@table, session_id)
    :ok
  end
end
