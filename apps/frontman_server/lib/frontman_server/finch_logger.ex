defmodule FrontmanServer.FinchLogger do
  @moduledoc """
  Telemetry handler for Finch HTTP client events.
  Logs HTTP request details while filtering sensitive headers.
  """

  require Logger

  @safe_headers ["content-type", "accept", "user-agent", "content-length", "host"]

  def handle_event(_event, _measurements, metadata, _config) do
    case metadata do
      %{
        request:
          %{
            method: method,
            host: host,
            port: port,
            path: path,
            scheme: scheme,
            headers: headers,
            body: body
          } = request
      } ->
        sanitized_headers = sanitize_headers(headers)
        # Include query string if present
        query = Map.get(request, :query, nil)
        url_with_query = if query && query != "", do: "#{path}?#{query}", else: path

        Logger.debug("""
        Finch Request:
          URL: #{method} #{scheme}://#{host}:#{port}#{url_with_query}
          Headers: #{inspect(sanitized_headers, pretty: true)}
          Body: #{inspect(body, pretty: true, limit: :infinity)}
        """)

      _ ->
        Logger.debug("Finch event with unexpected metadata: #{inspect(metadata)}")
    end

    :ok
  end

  defp sanitize_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      if String.downcase(key) in @safe_headers do
        {key, value}
      else
        {key, "[REDACTED]"}
      end
    end)
  end
end
