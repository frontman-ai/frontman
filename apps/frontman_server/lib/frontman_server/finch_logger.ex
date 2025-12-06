# lib/my_app/finch_logger.ex
defmodule FrontmanServer.FinchLogger do
  require Logger

  def handle_event(_event, _measurements, metadata, _config) do
    case metadata do
      %{
        request: %{
          method: method,
          host: host,
          port: port,
          path: path,
          scheme: scheme,
          headers: headers,
          body: body
        }
      } ->
        Logger.debug("""
        Finch Request:
          URL: #{method} #{scheme}://#{host}:#{port}#{path}
          Headers: #{inspect(headers, pretty: true)}
          Body: #{inspect(body, pretty: true, limit: :infinity)}
        """)

      _ ->
        Logger.debug("Finch event with unexpected metadata: #{inspect(metadata)}")
    end

    :ok
  end
end
