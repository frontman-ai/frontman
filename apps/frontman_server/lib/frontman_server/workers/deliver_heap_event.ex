defmodule FrontmanServer.Workers.DeliverHeapEvent do
  @moduledoc "Retries bounded Heap delivery with a stable provider idempotency key."

  use Oban.Worker,
    queue: :analytics,
    max_attempts: 8,
    unique: [
      keys: [:event_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable, :completed]
    ]

  alias FrontmanServer.Analytics

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    deliver(Analytics.config(), args)
  end

  defp deliver(config, args) do
    with true <- config[:enabled] == true,
         true <- permitted_identity?(args["identity"], config),
         app_id when is_binary(app_id) and byte_size(app_id) > 0 <- config[:app_id] do
      body = %{
        app_id: app_id,
        identity: args["identity"],
        event: args["event"],
        timestamp: args["timestamp"],
        idempotency_key: args["event_id"],
        properties: args["properties"]
      }

      Req.post("https://heapanalytics.com/api/track",
        json: body,
        retry: false,
        connect_options: [timeout: 2_000],
        receive_timeout: 5_000,
        redirect: false
      )
      |> result()
    else
      false -> {:cancel, :analytics_disabled}
      _ -> {:cancel, :heap_app_id_missing}
    end
  end

  defp permitted_identity?("onboarding:" <> _attempt, config),
    do: config[:anonymous_enabled] == true

  defp permitted_identity?("mcp_diagnostic:" <> _bucket, config),
    do: config[:anonymous_enabled] == true

  defp permitted_identity?(identity, _config), do: match?({:ok, _}, Ecto.UUID.cast(identity))

  defp result({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok
  defp result({:ok, %Req.Response{status: 429}}), do: {:error, :rate_limited}

  defp result({:ok, %Req.Response{status: status}}) when status >= 500,
    do: {:error, :heap_unavailable}

  defp result({:ok, %Req.Response{}}), do: {:cancel, :heap_rejected}
  defp result({:error, _reason}), do: {:error, :heap_transport_failed}
end
