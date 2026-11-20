defmodule FrontmanServer.OpenAIAds.CAPI do
  @moduledoc false
  @production Mix.env() == :prod

  def request(delivery, pixel, key) do
    registration? = delivery.kind == "registration_completed"

    event = %{
      id: delivery.id,
      timestamp_ms: delivery.timestamp_ms,
      action_source: "web",
      source_url: "https://frontman.sh/",
      opt_out: true,
      type: if(registration?, do: "registration_completed", else: "custom"),
      data: %{type: if(registration?, do: "customer_action", else: "custom")}
    }

    event =
      if delivery.kind == "first_successful_edit",
        do: Map.put(event, :custom_event_name, "first_successful_edit"),
        else: event

    event = if delivery.oppref, do: Map.put(event, :oppref, delivery.oppref), else: event

    Req.new(
      method: :post,
      url: "https://bzr.openai.com/v1/events",
      params: [pid: pixel],
      auth: {:bearer, key},
      json: %{events: [event]},
      retry: false,
      redirect: false,
      receive_timeout: 5_000,
      finch: [
        pool_timeout: 2_000,
        request_timeout: 7_000,
        conn_opts: [transport_opts: [timeout: 2_000]]
      ],
      decode_body: false,
      into: fn {:data, _body}, acc -> {:cont, acc} end
    )
  end

  def send(delivery) do
    config = Application.get_env(:frontman_server, FrontmanServer.OpenAIAds, [])

    with true <- Enum.all?([@production, FrontmanServer.OpenAIAds.enabled?()]),
         true <- delivery.timestamp_ms >= System.system_time(:millisecond) - 7 * 86_400_000 do
      case Req.request(request(delivery, config[:pixel_id], config[:capi_key])) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status}} when status == 429 or status in 500..599 ->
          {:error, :transient}

        {:ok, _response} ->
          {:discard, :permanent}

        {:error, _transport} ->
          {:error, :network}
      end
    else
      _disabled_or_expired -> {:discard, :disabled_or_expired}
    end
  end
end
