defmodule FrontmanServerWeb.Plugs.OpenAIAdsBoundary do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn
  alias FrontmanServer.OpenAIAds

  @impl true
  def init(_options) do
    Plug.Parsers.init(
      parsers: [:json],
      json_decoder: Jason,
      length: 4096,
      read_timeout: 5_000
    )
  end

  @impl true
  def call(conn, options) do
    case Enum.map(conn.path_info, &URI.decode/1) do
      ["ads", "attribution"] -> protect(conn, options)
      _other -> conn
    end
  end

  defp protect(conn, options) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    with true <- OpenAIAds.enabled?(),
         ["https://frontman.sh"] <- get_req_header(conn, "origin"),
         "" <- conn.query_string,
         true <- conn.method in ["POST", "DELETE", "OPTIONS"] do
      conn =
        conn
        |> put_resp_header("vary", "Origin")
        |> put_resp_header("access-control-allow-origin", "https://frontman.sh")
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header("access-control-allow-methods", "POST, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "content-type")

      if conn.method == "OPTIONS" do
        conn |> send_resp(204, "") |> halt()
      else
        conn = Plug.Parsers.call(conn, options)
        conn = put_private(conn, :openai_ads_params, conn.body_params)
        %{conn | params: %{}, body_params: %{}}
      end
    else
      _denied -> conn |> send_resp(403, "") |> halt()
    end
  end
end
