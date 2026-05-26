defmodule FrontmanNotifier.Discord do
  @moduledoc """
  Discord webhook client.
  """

  @timeout_ms 15_000

  @spec post_embed(String.t(), map()) :: :ok | {:error, term()}
  def post_embed(webhook_url, embed) when is_binary(webhook_url) and is_map(embed) do
    post(webhook_url, %{embeds: [embed]})
  end

  @spec post(String.t(), map()) :: :ok | {:error, term()}
  def post(webhook_url, payload) when is_binary(webhook_url) and is_map(payload) do
    case Req.post(webhook_url, json: payload, receive_timeout: @timeout_ms, retry: false) do
      {:ok, %{status: status}} when status in [200, 204] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:discord_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
