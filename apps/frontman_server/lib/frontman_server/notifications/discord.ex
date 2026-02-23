defmodule FrontmanServer.Notifications.Discord do
  @moduledoc """
  Listens for PostgreSQL NOTIFY events on the `new_user` channel and
  posts an alert to a Discord webhook (e.g. #new-users).

  Uses `Postgrex.Notifications` for push-based delivery — no polling.
  """

  use GenServer

  require Logger

  # ------------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ------------------------------------------------------------------
  # GenServer callbacks
  # ------------------------------------------------------------------

  @impl true
  def init(opts) do
    webhook_url = Keyword.fetch!(opts, :webhook_url)
    notifications_pid = Keyword.fetch!(opts, :notifications_pid)
    channel = Keyword.fetch!(opts, :channel)

    {:ok, listen_ref} = Postgrex.Notifications.listen(notifications_pid, channel)

    Logger.info("[Discord] Listening for new user notifications on PG channel '#{channel}'")

    {:ok, %{webhook_url: webhook_url, listen_ref: listen_ref}}
  end

  @impl true
  def handle_info({:notification, _pid, _ref, _channel, payload}, state) do
    case Jason.decode(payload) do
      {:ok, user} ->
        post_to_discord(state.webhook_url, user)

      {:error, reason} ->
        Logger.error("[Discord] Failed to decode notification payload: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ------------------------------------------------------------------
  # Internals
  # ------------------------------------------------------------------

  defp post_to_discord(webhook_url, user) do
    body = %{
      embeds: [
        %{
          title: "New User Signed Up",
          color: 0x57F287,
          fields: [
            %{name: "Name", value: user["name"] || "—", inline: true},
            %{name: "Email", value: user["email"] || "—", inline: true}
          ],
          timestamp: user["inserted_at"]
        }
      ]
    }

    case Req.post(webhook_url, json: body) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("[Discord] Posted new-user alert for #{user["email"]}")

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.warning("[Discord] Webhook returned #{status}: #{inspect(resp_body)}")

      {:error, reason} ->
        Logger.error("[Discord] Webhook request failed: #{inspect(reason)}")
    end
  end
end
