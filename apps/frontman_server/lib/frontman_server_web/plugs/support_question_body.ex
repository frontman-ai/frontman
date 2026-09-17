# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SupportQuestionBody do
  @moduledoc "Bounds public support requests before the general body parser runs."
  @behaviour Plug

  import Plug.Conn

  alias Plug.Conn.Utils

  @limit 32_768

  @impl Plug
  def init(_options) do
    Plug.Parsers.init(
      parsers: [:json],
      json_decoder: Jason,
      length: @limit,
      read_length: @limit,
      read_timeout: 5_000,
      body_reader: {__MODULE__, :read_body, []}
    )
  end

  @impl Plug
  def call(%{method: "POST", path_info: ["api", "support", "questions"]} = conn, options) do
    case get_req_header(conn, "content-type") do
      [content_type] ->
        case Utils.media_type(content_type) do
          {:ok, "application", "json", _params} -> parse(conn, options)
          _other -> reject(conn, 415, "Send application/json.")
        end

      _other ->
        reject(conn, 415, "Send application/json.")
    end
  end

  def call(conn, _options), do: conn

  def read_body(conn, options) do
    case Plug.Conn.read_body(conn, options) do
      {:ok, body, conn} when byte_size(body) > @limit -> {:more, body, conn}
      result -> result
    end
  end

  def scrub_params(%{path_info: ["api", "support", "questions"]}), do: %{}
  def scrub_params(conn), do: Sentry.PlugContext.default_body_scrubber(conn)

  defp parse(conn, options) do
    Plug.Parsers.call(conn, options)
  rescue
    Plug.Parsers.RequestTooLargeError -> reject(conn, 413, "Request body exceeds 32 KiB.")
    Plug.Parsers.ParseError -> reject(conn, 400, "Invalid JSON.")
    Plug.BadRequestError -> reject(conn, 400, "Could not read request body.")
    Plug.TimeoutError -> reject(conn, 408, "Request body timed out.")
  end

  defp reject(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
    |> halt()
  end
end
