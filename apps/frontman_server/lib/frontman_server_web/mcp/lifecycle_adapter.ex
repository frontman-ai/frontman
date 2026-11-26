defmodule FrontmanServerWeb.MCP.LifecycleAdapter do
  @moduledoc false
  @behaviour Plug.Conn.Adapter

  alias FrontmanServerWeb.MCP.Lifecycle

  @impl true
  def read_req_body({adapter, payload}, options) do
    case adapter.read_req_body(payload, options) do
      {:ok, body, payload} ->
        Lifecycle.request(body)
        {:ok, body, {adapter, payload}}

      {:more, body, payload} ->
        {:more, body, {adapter, payload}}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def send_resp({adapter, payload}, status, headers, body) do
    Lifecycle.response_started(status)
    {:ok, sent, payload} = adapter.send_resp(payload, status, headers, body)
    Lifecycle.response(status, body)
    {:ok, sent, {adapter, payload}}
  end

  @impl true
  def chunk({adapter, payload}, body) do
    result = adapter.chunk(payload, body)
    Lifecycle.chunk(body, result)

    case result do
      {:ok, sent, payload} -> {:ok, sent, {adapter, payload}}
      other -> other
    end
  end

  @impl true
  def send_chunked({adapter, payload}, status, headers) do
    Lifecycle.response_started(status)
    {:ok, sent, payload} = adapter.send_chunked(payload, status, headers)
    {:ok, sent, {adapter, payload}}
  end

  @impl true
  def send_file({adapter, payload}, status, headers, file, offset, length) do
    {:ok, sent, payload} = adapter.send_file(payload, status, headers, file, offset, length)
    {:ok, sent, {adapter, payload}}
  end

  @impl true
  def inform({adapter, payload}, status, headers) do
    case adapter.inform(payload, status, headers) do
      {:ok, payload} -> {:ok, {adapter, payload}}
      other -> other
    end
  end

  @impl true
  def upgrade({adapter, payload}, protocol, options) do
    case adapter.upgrade(payload, protocol, options) do
      {:ok, payload} -> {:ok, {adapter, payload}}
      other -> other
    end
  end

  @impl true
  def get_peer_data({adapter, payload}), do: adapter.get_peer_data(payload)

  @impl true
  def get_http_protocol({adapter, payload}), do: adapter.get_http_protocol(payload)

  @impl true
  def get_sock_data(adapter), do: Plug.Conn.get_sock_data(%Plug.Conn{adapter: adapter})

  @impl true
  def get_ssl_data(adapter), do: Plug.Conn.get_ssl_data(%Plug.Conn{adapter: adapter})

  @impl true
  def push({adapter, payload}, path, headers) do
    if function_exported?(adapter, :push, 3),
      do: adapter.push(payload, path, headers),
      else: {:error, :not_supported}
  end
end
