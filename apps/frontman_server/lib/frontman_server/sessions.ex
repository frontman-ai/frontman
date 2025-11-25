defmodule FrontmanServer.Sessions do
  @moduledoc """
  Public API for session management.

  Sessions represent authenticated client connections and own capabilities.
  This context manages the session lifecycle and capability registration.

  A session progresses through these states:
  - :connecting - Initial state when session is being set up
  - :awaiting_caps - Waiting for browser to announce capabilities
  - :ready - Capabilities registered, session can execute tasks
  - :disconnected - Browser disconnected but session still exists
  - :terminated - Session permanently closed
  """

  use TypedStruct

  @type session_state :: :awaiting_caps | :ready | :disconnected | :terminated

  typedstruct module: Session, enforce: true do
    @moduledoc """
    Domain entity representing a client session.

    Sessions own capabilities and tasks. Each browser tab = one session.
    """
    field :session_id, String.t()
    field :state, FrontmanServer.Sessions.session_state()
    field :capabilities, %{String.t() => Capability.t()}, default: %{}
    field :created_at, DateTime.t()
    field :disconnected_at, DateTime.t() | nil, enforce: false
    field :metadata, map(), default: %{}, enforce: false
  end

  typedstruct module: Capability, enforce: true do
    @moduledoc """
    A capability (tool) that can be executed by the browser.
    """
    field :name, String.t()
    field :description, String.t()
    field :input_schema, map()
    field :source, atom(), default: :mcp
  end

  @doc """
  Transitions session state based on events.

  Returns {:ok, new_state} or {:error, :invalid_transition}.
  """
  @spec transition(session_state(), atom()) ::
          {:ok, session_state()} | {:error, :invalid_transition}
  def transition(current_state, event) do
    case {current_state, event} do
      # Normal flow
      {:connecting, :init_complete} -> {:ok, :awaiting_caps}
      {:awaiting_caps, :capabilities_registered} -> {:ok, :ready}
      {:ready, :disconnected} -> {:ok, :disconnected}
      {:disconnected, :reconnect} -> {:ok, :awaiting_caps}
      # Terminal transition from any state
      {_, :terminate} -> {:ok, :terminated}
      # Invalid transitions
      _ -> {:error, :invalid_transition}
    end
  end

  # Public API

  alias FrontmanServer.Sessions.SessionStore

  @doc """
  Creates a new session.

  Sessions start in :connecting state.
  """
  @spec create_session(String.t()) :: {:ok, Session.t()}
  def create_session(session_id) do
    session = %Session{
      session_id: session_id,
      state: :awaiting_caps,
      capabilities: %{},
      created_at: DateTime.utc_now()
    }

    session
    |> SessionStore.insert()

    {:ok, session}
  end

  @doc """
  Registers capabilities for a session.

  Only valid in :awaiting_caps state. Transitions to :ready.
  Returns {:error, :invalid_state} if not in :awaiting_caps.
  """
  @spec register_capabilities(String.t(), list(map())) :: {:ok, Session.t()} | {:error, term()}
  def register_capabilities(session_id, capability_list) do
    case SessionStore.get(session_id) do
      {:ok, %{state: :awaiting_caps}} ->
        capabilities = parse_capabilities(capability_list)

        SessionStore.update(session_id, fn s ->
          %{s | capabilities: capabilities, state: :ready}
        end)

      {:ok, %{state: :ready}} ->
        {:error, :already_registered}

      {:ok, _} ->
        {:error, :invalid_state}

      error ->
        error
    end
  end

  @doc """
  Marks session as disconnected.

  Stores timestamp for cleanup purposes.
  """
  @spec mark_disconnected(String.t()) :: {:ok, Session.t()} | {:error, term()}
  def mark_disconnected(session_id) do
    SessionStore.update(session_id, fn session ->
      %{session | state: :disconnected, disconnected_at: DateTime.utc_now()}
    end)
  end

  @doc """
  Prepares session for reconnection.

  Transitions :disconnected -> :awaiting_caps (capabilities must be re-announced).
  """
  @spec prepare_reconnect(String.t()) :: {:ok, Session.t()} | {:error, term()}
  def prepare_reconnect(session_id) do
    case SessionStore.get(session_id) do
      {:ok, %{state: :disconnected}} ->
        SessionStore.update(session_id, fn s ->
          case transition(s.state, :reconnect) do
            {:ok, new_state} ->
              %{s | state: new_state, disconnected_at: nil, capabilities: %{}}

            {:error, _} ->
              s
          end
        end)

      {:ok, _} ->
        {:error, :not_disconnected}

      error ->
        error
    end
  end

  @doc """
  Gets a session by ID.
  """
  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  defdelegate get_session(session_id), to: SessionStore, as: :get

  @doc """
  Checks if session exists.
  """
  @spec session_exists?(String.t()) :: boolean()
  defdelegate session_exists?(session_id), to: SessionStore, as: :exists?

  # Private helpers

  defp parse_capabilities(capability_list) when is_list(capability_list) do
    capability_list
    |> Enum.map(fn cap ->
      capability = %Capability{
        name: cap["name"] || cap[:name],
        description: cap["description"] || cap[:description] || "",
        input_schema: cap["inputSchema"] || cap[:input_schema] || %{},
        source: :mcp
      }

      {capability.name, capability}
    end)
    |> Enum.into(%{})
  end
end
