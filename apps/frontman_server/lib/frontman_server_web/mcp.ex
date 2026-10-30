defmodule FrontmanServerWeb.MCP do
  @moduledoc false
  import Plug.Conn

  alias Anubis.Server.Supervisor, as: AnubisSupervisor
  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug
  alias Anubis.Server.Transport.WellKnown
  alias FrontmanServerWeb.MCP.{DenyAll, Origin, Server}

  def child_specs do
    {:ok, resource, issuer, _origin} = config()

    [
      {Server,
       transport: {:streamable_http, start: true},
       authorization: [
         resource: resource,
         authorization_servers: [issuer],
         validator: {DenyAll, []}
       ]}
    ]
  end

  defp config do
    config = Application.fetch_env!(:frontman_server, :mcp_server)

    with {:ok, origin} <- Origin.resource(config[:resource]),
         :ok <- Origin.issuer(config[:issuer]) do
      {:ok, config[:resource], config[:issuer], origin}
    end
  end

  def available? do
    with {:ok, resource, issuer, _origin} <- config(),
         %{resource: ^resource, authorization_servers: [^issuer], validator: {DenyAll, []}} <-
           AnubisSupervisor.get_authorization_config(Server),
         pid when is_pid(pid) <- Process.whereis(Anubis.Server.Registry.supervisor_name(Server)) do
      true
    else
      _ -> false
    end
  end

  def guard(conn) do
    with true <- available?(),
         {:ok, _, _, origin} <- config(),
         true <- headers_allowed?(conn, origin) do
      conn
    else
      false -> reject(conn, if(available?(), do: 403, else: 503))
      _ -> reject(conn, 503)
    end
  end

  def call(conn) do
    conn = guard(conn)

    if conn.halted do
      conn
    else
      AnubisPlug.call(conn, AnubisPlug.init(server: Server))
    end
  end

  defp headers_allowed?(conn, origin) do
    origins = get_req_header(conn, "origin")
    authorizations = get_req_header(conn, "authorization")

    length(origins) <= 1 and length(authorizations) <= 1 and
      Enum.all?(origins, &Origin.allowed?(origin, &1))
  end

  def metadata(conn, _opts) do
    if available?() do
      WellKnown.call(conn, %{server: Server})
    else
      reject(conn, 503)
    end
  end

  defp reject(conn, status), do: conn |> send_resp(status, "") |> halt()
end
