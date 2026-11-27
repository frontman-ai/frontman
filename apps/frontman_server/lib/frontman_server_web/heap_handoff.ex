defmodule FrontmanServerWeb.HeapHandoff do
  @moduledoc "Delivers signed-in MCP handoff events to the same Heap identity as the embedded client."
  use Oban.Worker, queue: :default, max_attempts: 8
  require Logger
  alias FrontmanServerWeb.MCP.HandoffEvent

  def attach do
    case :telemetry.attach(
           __MODULE__,
           HandoffEvent.telemetry_name(),
           &__MODULE__.enqueue/4,
           nil
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  def enqueue(_, _, %HandoffEvent{user_id: nil}, _), do: :ok

  def enqueue(_, _, %HandoffEvent{} = event, _) do
    if app_id = Application.get_env(:frontman_server, :heap_app_id) do
      payload = HandoffEvent.heap_payload(event, app_id)

      case Oban.insert(new(payload), timeout: 500) do
        {:ok, _} -> :ok
        {:error, _} -> Logger.warning("Could not enqueue Heap handoff event")
      end
    end
  rescue
    # A failed observer must not break login or be detached by :telemetry.
    _error in [DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.warning("Database unavailable for Heap handoff event")
  end

  @impl true
  def perform(%Oban.Job{args: payload}) do
    if payload["app_id"] == Application.get_env(:frontman_server, :heap_app_id) do
      case Req.post("https://heapanalytics.com/api/track",
             json: payload,
             redirect: false,
             retry: false,
             connect_options: [timeout: 2_000],
             receive_timeout: 5_000
           ) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: status}} when status == 429 or status >= 500 -> {:error, {:http, status}}
        {:ok, %{status: status}} -> {:cancel, {:http, status}}
        {:error, _} -> {:error, :heap_unreachable}
      end
    else
      {:cancel, :heap_environment_changed}
    end
  end
end
