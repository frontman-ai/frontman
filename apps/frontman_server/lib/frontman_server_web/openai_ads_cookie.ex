defmodule FrontmanServerWeb.OpenAIAdsCookie do
  @moduledoc false
  import Plug.Conn

  @name "__Host-frontman_openai_ads"
  @options [sign: true, http_only: true, secure: true, same_site: "Lax", path: "/"]

  def id(conn) do
    conn = fetch_cookies(conn, signed: [@name])
    conn.cookies[@name]
  end

  def put(conn, id, expires_at) do
    options = Keyword.put(@options, :max_age, DateTime.diff(expires_at, DateTime.utc_now()))
    put_resp_cookie(conn, @name, id, options)
  end

  def delete(conn), do: delete_resp_cookie(conn, @name, @options)
end
