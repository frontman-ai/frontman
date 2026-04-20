# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxy do
  @moduledoc """
  Endpoint-level preview proxy for `{sandbox_id}.preview.<domain>` hosts.

  Handles owner authentication/authorization and proxies HTTP + WebSocket
  traffic to the sandbox preview upstream target.
  """

  @behaviour Plug

  require Logger

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias FrontmanServer.Sandboxes
  alias FrontmanServerWeb.UserAuth

  @hop_by_hop_headers MapSet.new([
                        "connection",
                        "keep-alive",
                        "proxy-authenticate",
                        "proxy-authorization",
                        "proxy-connection",
                        "te",
                        "trailer",
                        "transfer-encoding",
                        "upgrade"
                      ])

  @blocked_cookie_names ["_frontman_server_key", "_frontman_server_web_user_remember_me"]

  @ws_forward_headers ["origin", "cookie", "user-agent", "sec-websocket-protocol"]

  @impl true
  def init(opts) do
    configured_opts = Application.get_env(:frontman_server, :sandbox_preview_proxy, [])
    Keyword.merge(configured_opts, opts)
  end

  @impl true
  def call(conn, opts) do
    preview_base_host = Keyword.get(opts, :preview_base_host)

    case extract_sandbox_id(conn.host, preview_base_host) do
      {:ok, sandbox_id} -> handle_preview_request(conn, sandbox_id, opts)
      :not_preview_host -> conn
      :invalid_preview_host -> not_found(conn)
    end
  end

  defp handle_preview_request(conn, sandbox_id, opts) do
    conn =
      conn
      |> fetch_session()
      |> UserAuth.fetch_current_scope_for_user([])

    case conn.assigns.current_scope do
      %{user: %{id: _}} = scope ->
        proxy_for_scope(conn, scope, sandbox_id, opts)

      _ ->
        handle_unauthenticated(conn, opts)
    end
  end

  defp proxy_for_scope(conn, scope, sandbox_id, opts) do
    case Sandboxes.resolve_preview_target(scope, sandbox_id) do
      {:ok, target} ->
        case websocket_upgrade?(conn) do
          true -> proxy_websocket(conn, target, opts)
          false -> proxy_http(conn, target, opts)
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :unavailable} ->
        service_unavailable(conn)
    end
  end

  defp handle_unauthenticated(conn, opts) do
    case websocket_upgrade?(conn) do
      true -> unauthorized(conn)
      false -> redirect_to_login(conn, opts)
    end
  end

  defp redirect_to_login(conn, opts) do
    return_to = current_request_url(conn)
    query = URI.encode_query(%{"return_to" => return_to})

    case Keyword.get(opts, :app_login_host) do
      host when is_binary(host) and byte_size(host) > 0 ->
        login_url =
          build_absolute_url(
            login_scheme(opts, conn.scheme),
            host,
            Keyword.get(opts, :app_login_port),
            "/users/log-in",
            query
          )

        conn
        |> redirect(external: login_url)
        |> halt()

      _ ->
        conn
        |> redirect(to: "/users/log-in?#{query}")
        |> halt()
    end
  end

  defp proxy_http(conn, target, opts) do
    with {:ok, body, conn} <- read_full_body(conn, []),
         {:ok, response} <- request_upstream(conn, target, body, opts) do
      case stream_upstream_response(conn, response, opts) do
        {:ok, conn} ->
          halt(conn)

        {:error, conn, reason} ->
          Req.cancel_async_response(response)

          Logger.warning(
            "[SandboxPreviewProxy] upstream stream failed after response started: #{inspect(reason)}"
          )

          halt(conn)
      end
    else
      {:error, reason} ->
        Logger.warning("[SandboxPreviewProxy] upstream request failed: #{inspect(reason)}")
        bad_gateway(conn)
    end
  end

  defp proxy_websocket(conn, target, opts) do
    state = %{
      upstream_host: target.host,
      upstream_port: target.port,
      upstream_path: conn.request_path,
      upstream_query: conn.query_string,
      upstream_headers: websocket_forward_headers(conn.req_headers, opts),
      connect_timeout_ms: Keyword.get(opts, :upstream_connect_timeout_ms, 5_000),
      upgrade_timeout_ms: Keyword.get(opts, :websocket_upgrade_timeout_ms, 5_000)
    }

    conn
    |> WebSockAdapter.upgrade(
      FrontmanServerWeb.SandboxPreviewSocket,
      state,
      timeout: Keyword.get(opts, :websocket_idle_timeout_ms, 60_000)
    )
    |> halt()
  rescue
    error in WebSockAdapter.UpgradeError ->
      Logger.warning(
        "[SandboxPreviewProxy] websocket upgrade failed: #{Exception.message(error)}"
      )

      bad_gateway(conn)
  end

  defp request_upstream(conn, target, body, opts) do
    Req.request(
      method: conn.method,
      url: upstream_url(conn, target),
      headers: request_forward_headers(conn, opts),
      body: body,
      connect_options: [timeout: Keyword.get(opts, :upstream_connect_timeout_ms, 5_000)],
      receive_timeout: Keyword.get(opts, :upstream_receive_timeout_ms, 30_000),
      retry: false,
      into: :self
    )
  end

  defp stream_upstream_response(conn, response, opts) do
    conn =
      response
      |> Req.get_headers_list()
      |> strip_hop_by_hop_headers()
      |> strip_disallowed_response_headers()
      |> Enum.reduce(conn, fn {name, value}, acc -> put_resp_header(acc, name, value) end)
      |> send_chunked(response.status)

    stream_timeout_ms = Keyword.get(opts, :upstream_stream_timeout_ms, 30_000)
    receive_upstream_chunks(conn, response, stream_timeout_ms)
  end

  defp receive_upstream_chunks(conn, response, timeout_ms) do
    receive do
      message ->
        case Req.parse_message(response, message) do
          {:ok, chunks} ->
            case relay_chunks(conn, chunks) do
              {:ok, conn} -> receive_upstream_chunks(conn, response, timeout_ms)
              {:done, conn} -> {:ok, conn}
              {:error, conn, reason} -> {:error, conn, reason}
            end

          :unknown ->
            receive_upstream_chunks(conn, response, timeout_ms)

          {:error, reason} ->
            {:error, conn, reason}
        end
    after
      timeout_ms ->
        Req.cancel_async_response(response)
        {:error, conn, :upstream_timeout}
    end
  end

  defp relay_chunks(conn, chunks) do
    Enum.reduce_while(chunks, {:ok, conn}, fn
      :done, {:ok, conn} ->
        {:halt, {:done, conn}}

      {:trailers, _}, {:ok, conn} ->
        {:cont, {:ok, conn}}

      {:data, data}, {:ok, conn} ->
        case chunk(conn, data) do
          {:ok, conn} -> {:cont, {:ok, conn}}
          {:error, reason} -> {:halt, {:error, conn, reason}}
        end
    end)
  end

  defp read_full_body(conn, chunks) do
    case read_body(conn) do
      {:ok, body, conn} ->
        full_body =
          chunks
          |> Enum.reverse([body])
          |> IO.iodata_to_binary()

        {:ok, full_body, conn}

      {:more, body, conn} ->
        read_full_body(conn, [body | chunks])

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_forward_headers(conn, opts) do
    conn.req_headers
    |> strip_hop_by_hop_headers()
    |> scrub_cookie_headers(blocked_cookie_names(opts))
    |> Enum.reject(fn {name, _} -> String.downcase(name) == "host" end)
    |> prepend_forwarding_headers(conn)
  end

  defp websocket_forward_headers(headers, opts) do
    headers
    |> Enum.filter(fn {name, _value} -> String.downcase(name) in @ws_forward_headers end)
    |> scrub_cookie_headers(blocked_cookie_names(opts))
  end

  defp blocked_cookie_names(opts) do
    opts
    |> Keyword.get(:blocked_cookie_names, @blocked_cookie_names)
    |> MapSet.new()
  end

  defp scrub_cookie_headers(headers, blocked_cookie_names) do
    headers
    |> Enum.reduce([], fn header, acc ->
      case scrub_header(header, blocked_cookie_names) do
        nil -> acc
        scrubbed_header -> [scrubbed_header | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp scrub_header({name, value}, blocked_cookie_names) do
    case String.downcase(name) do
      "cookie" ->
        scrubbed_value = scrub_cookie_header(value, blocked_cookie_names)

        if scrubbed_value == "" do
          nil
        else
          {name, scrubbed_value}
        end

      _ ->
        {name, value}
    end
  end

  defp scrub_cookie_header(value, blocked_cookie_names) do
    value
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn cookie_pair ->
      MapSet.member?(blocked_cookie_names, cookie_name(cookie_pair))
    end)
    |> Enum.join("; ")
  end

  defp cookie_name(cookie_pair) do
    cookie_pair
    |> String.split("=", parts: 2)
    |> List.first()
    |> to_string()
    |> String.trim()
  end

  defp prepend_forwarding_headers(headers, conn) do
    forwarded_headers = [
      {"x-forwarded-for", format_remote_ip(conn.remote_ip)},
      {"x-forwarded-host", conn.host},
      {"x-forwarded-port", Integer.to_string(conn.port)},
      {"x-forwarded-proto", Atom.to_string(conn.scheme)}
    ]

    forwarded_headers ++ headers
  end

  defp format_remote_ip({_, _, _, _} = ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_remote_ip({_, _, _, _, _, _, _, _} = ip), do: ip |> :inet.ntoa() |> to_string()

  defp upstream_url(conn, target) do
    build_absolute_url("http", target.host, target.port, conn.request_path, conn.query_string)
  end

  defp current_request_url(conn) do
    build_absolute_url(
      Atom.to_string(conn.scheme),
      conn.host,
      conn.port,
      conn.request_path,
      conn.query_string
    )
  end

  defp build_absolute_url(scheme, host, port, path, query) do
    authority =
      case normalize_port(port) do
        nil -> host
        80 when scheme == "http" -> host
        443 when scheme == "https" -> host
        normalized_port -> "#{host}:#{normalized_port}"
      end

    case blank_to_nil(query) do
      nil -> "#{scheme}://#{authority}#{path}"
      normalized_query -> "#{scheme}://#{authority}#{path}?#{normalized_query}"
    end
  end

  defp login_scheme(opts, request_scheme) do
    case Keyword.get(opts, :app_login_scheme) do
      nil ->
        Atom.to_string(request_scheme)

      scheme when is_atom(scheme) ->
        Atom.to_string(scheme)

      scheme when is_binary(scheme) and byte_size(scheme) > 0 ->
        scheme

      _ ->
        Atom.to_string(request_scheme)
    end
  end

  defp strip_hop_by_hop_headers(headers) do
    connection_headers =
      headers
      |> Enum.filter(fn {name, _} -> String.downcase(name) == "connection" end)
      |> Enum.flat_map(fn {_name, value} ->
        value
        |> String.split(",", trim: true)
        |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
      end)
      |> MapSet.new()

    blocked_headers =
      @hop_by_hop_headers
      |> MapSet.union(connection_headers)
      |> MapSet.put("content-length")

    Enum.reject(headers, fn {name, _value} ->
      MapSet.member?(blocked_headers, String.downcase(name))
    end)
  end

  defp strip_disallowed_response_headers(headers) do
    Enum.reject(headers, fn {name, _value} ->
      String.downcase(name) == "set-cookie"
    end)
  end

  defp websocket_upgrade?(conn) do
    upgrade_websocket? =
      conn
      |> get_req_header("upgrade")
      |> Enum.any?(&(String.downcase(String.trim(&1)) == "websocket"))

    connection_upgrade? =
      conn
      |> get_req_header("connection")
      |> Enum.any?(fn value ->
        value
        |> String.split(",", trim: true)
        |> Enum.any?(&(String.downcase(String.trim(&1)) == "upgrade"))
      end)

    upgrade_websocket? and connection_upgrade?
  end

  defp extract_sandbox_id(_host, preview_base_host)
       when not is_binary(preview_base_host) or byte_size(preview_base_host) == 0,
       do: :not_preview_host

  defp extract_sandbox_id(host, preview_base_host) when is_binary(host) do
    normalized_host = String.downcase(host)
    normalized_base_host = String.downcase(preview_base_host)
    suffix = ".#{normalized_base_host}"

    cond do
      normalized_host == normalized_base_host ->
        :invalid_preview_host

      String.ends_with?(normalized_host, suffix) ->
        sandbox_id = String.replace_suffix(normalized_host, suffix, "")

        case valid_sandbox_id?(sandbox_id) do
          true -> {:ok, sandbox_id}
          false -> :invalid_preview_host
        end

      true ->
        :not_preview_host
    end
  end

  defp valid_sandbox_id?(sandbox_id) do
    sandbox_id != "" and match?({:ok, _}, Ecto.UUID.cast(sandbox_id))
  end

  defp normalize_port(port) when is_integer(port) and port > 0, do: port
  defp normalize_port(_), do: nil

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp unauthorized(conn) do
    conn
    |> send_resp(:unauthorized, "authentication_required")
    |> halt()
  end

  defp bad_gateway(conn) do
    conn
    |> send_resp(:bad_gateway, "upstream_unreachable")
    |> halt()
  end

  defp service_unavailable(conn) do
    conn
    |> send_resp(:service_unavailable, "sandbox_unavailable")
    |> halt()
  end

  defp not_found(conn) do
    conn
    |> send_resp(:not_found, "not_found")
    |> halt()
  end
end
