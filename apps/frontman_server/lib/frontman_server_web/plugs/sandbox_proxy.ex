# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SandboxProxy do
  @moduledoc """
  Proxies sandbox preview URLs through the Frontman API origin.

  This is intentionally temporary: callers pass the sandbox URL in the `url`
  query parameter until sandbox lookup is modeled by id.
  """

  import Plug.Conn

  alias FrontmanServerWeb.Plugs.SandboxProxy.Daytona, as: TargetPolicy
  alias FrontmanServerWeb.Plugs.SandboxProxy.FrontmanRuntime, as: RuntimePolicy
  alias FrontmanServerWeb.Plugs.SandboxProxy.Vite, as: DevServerPolicy
  alias FrontmanServerWeb.Plugs.SandboxProxy.WebSocket

  require Logger

  @behaviour Plug

  # Preserve RFC 3986 pchar reserved characters that are legal inside one path
  # segment. Dev servers use these characters as path syntax, e.g. Vite routes
  # like /@fs and scoped packages like /node_modules/@scope/pkg. Encoding them
  # to %40/%3A/etc. changes upstream routing, while / remains encoded by being
  # represented as the segment separator when we join path_info below.
  @path_segment_reserved_chars ~c"!$&'()*+,;=:@"
  @source_url_cookie "_frontman_sandbox_source_url"
  @source_url_cookie_max_age_seconds 3_600
  @websocket_idle_timeout_ms 60_000
  @websocket_max_frame_size 10_485_760
  @read_timeout_ms 30_000
  @receive_timeout_ms 30_000
  @max_request_body_bytes 10_485_760
  @target_policy_error_reasons [:invalid_url, :unsupported_host, :unsupported_scheme]
  @request_headers_blocklist MapSet.new([
                               "accept-encoding",
                               "authorization",
                               "connection",
                               "content-length",
                               "cookie",
                               "host",
                               "keep-alive",
                               "proxy-authenticate",
                               "proxy-authorization",
                               "te",
                               "trailer",
                               "transfer-encoding",
                               "upgrade"
                             ])
  @websocket_request_headers_blocklist MapSet.new([
                                         "authorization",
                                         "content-length",
                                         "cookie",
                                         "connection",
                                         "host",
                                         "keep-alive",
                                         "proxy-authenticate",
                                         "proxy-authorization",
                                         "sec-websocket-accept",
                                         "sec-websocket-extensions",
                                         "sec-websocket-key",
                                         "sec-websocket-protocol",
                                         "sec-websocket-version",
                                         "te",
                                         "trailer",
                                         "transfer-encoding",
                                         "upgrade"
                                       ])
  @response_headers_blocklist MapSet.new([
                                "connection",
                                "content-length",
                                "keep-alive",
                                "proxy-authenticate",
                                "proxy-authorization",
                                "set-cookie",
                                "te",
                                "trailer",
                                "transfer-encoding",
                                "upgrade"
                              ])

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    respond_to_control_request(conn, TargetPolicy.control_request(conn))
  end

  defp respond_to_control_request(conn, :not_handled), do: proxy_request(conn)

  defp respond_to_control_request(conn, {:redirect, redirect_path}) do
    conn
    |> Phoenix.Controller.redirect(to: redirect_path)
    |> halt()
  end

  defp respond_to_control_request(conn, {:error, status, message}) do
    send_error(conn, status, message)
  end

  defp proxy_request(%{path_info: ["frontman" | _proxied_path]} = conn) do
    case conn.method do
      "OPTIONS" -> send_preflight(conn)
      _ -> proxy_frontman_path(conn, proxied_path_from_request(conn, 0))
    end
  end

  defp proxy_request(%{path_info: ["sandbox" | _proxied_path]} = conn) do
    case conn.method do
      "OPTIONS" -> send_preflight(conn)
      _ -> proxy(conn, proxied_path_from_request(conn, 1))
    end
  end

  defp proxy_request(conn) do
    case DevServerPolicy.websocket_request?(conn) do
      true -> proxy_websocket(conn)
      false -> proxy_referred_path(conn)
    end
  end

  defp proxy_websocket(conn) do
    case source_url_for_websocket(conn) do
      {:ok, raw_url} -> upgrade_websocket(conn, raw_url)
      {:error, :missing_url} -> send_error(conn, :bad_request, "Missing url query parameter")
    end
  end

  defp source_url_for_websocket(conn) do
    case source_url(conn) do
      {:ok, raw_url} -> {:ok, raw_url}
      {:error, :missing_url} -> source_url_from_cookie(conn)
    end
  end

  defp upgrade_websocket(conn, raw_url) do
    with :ok <- TargetPolicy.validate_target_url(raw_url),
         {:ok, target_url} <- build_websocket_target_url(raw_url, conn) do
      conn
      |> put_resp_header("sec-websocket-protocol", DevServerPolicy.websocket_protocol())
      |> WebSockAdapter.upgrade(
        WebSocket,
        %{
          target_url: target_url,
          upstream_headers: proxy_websocket_request_headers(conn.req_headers)
        },
        timeout: @websocket_idle_timeout_ms,
        max_frame_size: @websocket_max_frame_size
      )
      |> halt()
    else
      {:error, reason} when reason in @target_policy_error_reasons ->
        send_target_policy_error(conn, reason)
    end
  end

  defp build_websocket_target_url(raw_url, conn) do
    raw_url
    |> target_origin()
    |> URI.parse()
    |> put_request_path(proxied_path_from_request(conn, 0))
    |> put_raw_query(conn.query_string)
    |> websocket_url_string()
  end

  defp websocket_url_string(%URI{scheme: "https"} = uri) do
    {:ok, URI.to_string(%{uri | scheme: "wss"})}
  end

  defp websocket_url_string(%URI{scheme: "http"} = uri) do
    {:ok, URI.to_string(%{uri | scheme: "ws"})}
  end

  defp websocket_url_string(%URI{}), do: {:error, :unsupported_scheme}

  defp proxy(%{query_params: %{"url" => raw_url}} = conn, proxied_path)
       when is_binary(raw_url) do
    run_proxy(conn, build_target_url(raw_url, proxied_path, conn.query_params))
  end

  defp proxy(conn, _proxied_path) do
    send_error(conn, :bad_request, "Missing url query parameter")
  end

  defp proxy_frontman_path(conn, proxied_path) do
    case source_url(conn) do
      {:ok, raw_url} ->
        run_proxy(conn, build_target_url_for_path(raw_url, proxied_path, conn.query_params))

      {:error, :missing_url} ->
        send_error(conn, :bad_request, "Missing url query parameter")
    end
  end

  defp proxy_referred_path(conn) do
    case source_url_for_referred_path(conn) do
      {:ok, raw_url} ->
        run_proxy(
          conn,
          build_target_url_for_referred_path(
            raw_url,
            proxied_path_from_request(conn, 0),
            conn.query_string
          )
        )

      {:error, :missing_url} ->
        conn
    end
  end

  defp source_url_for_referred_path(conn) do
    case source_url_from_referer(conn) do
      {:ok, raw_url} -> {:ok, raw_url}
      {:error, :missing_url} -> source_url_from_asset_cookie(conn)
    end
  end

  defp source_url_from_asset_cookie(conn) do
    case DevServerPolicy.dev_asset_path?(conn.path_info) do
      true -> source_url_from_cookie(conn)
      false -> {:error, :missing_url}
    end
  end

  defp run_proxy(conn, {:ok, target_url}) do
    with :ok <- TargetPolicy.validate_target_url(target_url),
         {:ok, body, conn} <- read_proxy_body(conn),
         {:ok, response} <- request_target(conn, target_url, body) do
      send_proxy_response(conn, target_url, response)
    else
      {:error, reason} when reason in @target_policy_error_reasons ->
        send_target_policy_error(conn, reason)

      {:error, :request_body_too_large} ->
        send_error(conn, :payload_too_large, "Request body too large")

      {:error, :upstream_timeout} ->
        send_error(conn, :gateway_timeout, "Sandbox request timed out")

      {:error, :unsupported_method} ->
        send_error(conn, :method_not_allowed, "Unsupported HTTP method")

      {:error, reason} ->
        send_bad_gateway(conn, reason)
    end
  end

  defp build_target_url(raw_url, [], query_params) do
    raw_url
    |> URI.parse()
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  defp build_target_url(raw_url, proxied_path, query_params) do
    raw_url
    |> URI.parse()
    |> put_proxied_path(proxied_path)
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  defp build_target_url_for_path(raw_url, proxied_path, query_params) do
    raw_url
    |> URI.parse()
    |> put_request_path(proxied_path)
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  defp build_target_url_for_referred_path(raw_url, proxied_path, query_string) do
    raw_url
    |> URI.parse()
    |> put_request_path(proxied_path)
    |> put_raw_query(query_string)
    |> then(&{:ok, URI.to_string(&1)})
  end

  defp proxied_path_from_request(conn, drop_segments) do
    conn.path_info
    |> Enum.drop(drop_segments)
    |> maybe_keep_trailing_slash(conn.request_path)
  end

  defp maybe_keep_trailing_slash(proxied_path, request_path) do
    case String.ends_with?(request_path, "/") do
      true -> proxied_path ++ [""]
      false -> proxied_path
    end
  end

  defp put_request_path(%URI{} = uri, proxied_path) do
    encoded_path = Enum.map_join(proxied_path, "/", &encode_path_segment/1)
    %{uri | path: "/" <> encoded_path, query: nil, fragment: nil}
  end

  defp put_raw_query(%URI{} = uri, ""), do: uri
  defp put_raw_query(%URI{} = uri, query_string), do: %{uri | query: query_string}

  defp source_url(%{query_params: %{"url" => raw_url}}) when is_binary(raw_url) do
    {:ok, raw_url}
  end

  defp source_url(conn), do: source_url_from_referer(conn)

  defp source_url_from_referer(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] -> source_url_from_referer_url(referer)
      _ -> {:error, :missing_url}
    end
  end

  defp source_url_from_referer_url(referer) do
    case URI.parse(referer) do
      %URI{query: query} when is_binary(query) -> source_url_from_query(query)
      _ -> {:error, :missing_url}
    end
  end

  defp source_url_from_query(query) do
    case URI.decode_query(query) do
      %{"url" => raw_url} when is_binary(raw_url) -> {:ok, raw_url}
      _ -> {:error, :missing_url}
    end
  end

  defp source_url_from_cookie(conn) do
    cookies = fetch_cookies(conn).req_cookies

    case Map.fetch(cookies, @source_url_cookie) do
      {:ok, encoded_url} -> decode_source_url_cookie(encoded_url)
      :error -> {:error, :missing_url}
    end
  end

  defp decode_source_url_cookie(encoded_url) do
    case Base.url_decode64(encoded_url, padding: false) do
      {:ok, raw_url} -> {:ok, raw_url}
      :error -> {:error, :missing_url}
    end
  end

  defp put_proxied_path(%URI{} = uri, proxied_path) do
    %{uri | path: join_url_paths(uri.path, proxied_path)}
  end

  defp join_url_paths(base_path, proxied_path) when is_list(proxied_path) do
    encoded_path = Enum.map_join(proxied_path, "/", &encode_path_segment/1)

    case String.trim_trailing(base_path || "", "/") do
      "" -> "/" <> encoded_path
      prefix -> prefix <> "/" <> encoded_path
    end
  end

  defp encode_path_segment(segment) do
    URI.encode(segment, &path_segment_char?/1)
  end

  defp path_segment_char?(char) do
    URI.char_unreserved?(char) or char in @path_segment_reserved_chars
  end

  defp put_merged_query(%URI{} = uri, query_params, query_mode) do
    forwarded_query =
      query_params
      |> forwarded_query_params(query_mode)
      |> URI.encode_query(:rfc3986)

    %{uri | query: merge_query(uri.query, forwarded_query)}
  end

  defp forwarded_query_params(query_params, :drop_proxy_url), do: Map.delete(query_params, "url")

  defp merge_query(nil, ""), do: nil
  defp merge_query("", ""), do: nil
  defp merge_query(query, "") when is_binary(query), do: query
  defp merge_query(nil, forwarded_query), do: forwarded_query
  defp merge_query("", forwarded_query), do: forwarded_query
  defp merge_query(query, forwarded_query), do: query <> "&" <> forwarded_query

  defp read_proxy_body(conn) do
    case body_allowed?(conn.method) do
      true -> read_limited_body(conn, [])
      false -> {:ok, nil, conn}
    end
  end

  defp body_allowed?(method) do
    case method do
      "GET" -> false
      "HEAD" -> false
      "OPTIONS" -> false
      _ -> true
    end
  end

  defp read_limited_body(conn, chunks) do
    case read_body(conn, length: @max_request_body_bytes, read_timeout: @read_timeout_ms) do
      {:ok, chunk, conn} -> {:ok, IO.iodata_to_binary(Enum.reverse([chunk | chunks])), conn}
      {:more, _chunk, _conn} -> {:error, :request_body_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_target(conn, target_url, body) do
    with {:ok, options} <- request_options(conn, target_url, body) do
      options
      |> Req.request()
      |> normalize_response()
    end
  end

  defp request_options(conn, target_url, body) do
    with {:ok, method} <- req_method(conn.method) do
      options =
        [
          method: method,
          url: target_url,
          headers: proxy_request_headers(conn.req_headers),
          receive_timeout: @receive_timeout_ms,
          compressed: false,
          decode_body: false,
          redirect: false
        ]
        |> Keyword.merge(req_options())
        |> maybe_put_body(body)

      {:ok, options}
    end
  end

  defp maybe_put_body(opts, nil), do: opts
  defp maybe_put_body(opts, body), do: Keyword.put(opts, :body, body)

  defp req_method("GET"), do: {:ok, :get}
  defp req_method("POST"), do: {:ok, :post}
  defp req_method("PUT"), do: {:ok, :put}
  defp req_method("PATCH"), do: {:ok, :patch}
  defp req_method("DELETE"), do: {:ok, :delete}
  defp req_method("HEAD"), do: {:ok, :head}
  defp req_method(_method), do: {:error, :unsupported_method}

  defp proxy_request_headers(headers) do
    headers
    |> Enum.reject(fn {name, _value} -> MapSet.member?(@request_headers_blocklist, name) end)
    |> TargetPolicy.put_request_headers()
  end

  defp proxy_websocket_request_headers(headers) do
    headers
    |> Enum.reject(fn {name, _value} ->
      MapSet.member?(@websocket_request_headers_blocklist, name)
    end)
    |> DevServerPolicy.put_websocket_protocol_header()
    |> TargetPolicy.put_request_headers()
  end

  defp normalize_response({:ok, %Req.Response{} = response}), do: {:ok, response}

  defp normalize_response({:error, %Req.TransportError{reason: :timeout}}) do
    {:error, :upstream_timeout}
  end

  defp normalize_response({:error, reason}), do: {:error, reason}

  defp send_proxy_response(conn, target_url, %Req.Response{} = response) do
    conn
    |> put_proxy_response_headers(target_url, response.headers)
    |> put_source_url_cookie(target_url)
    |> put_cors_headers()
    |> send_resp(response.status, response_body(conn, target_url, response))
    |> halt()
  end

  defp put_source_url_cookie(conn, target_url) do
    put_resp_cookie(
      conn,
      @source_url_cookie,
      target_url |> target_origin() |> encode_source_url_cookie(),
      http_only: true,
      max_age: @source_url_cookie_max_age_seconds,
      same_site: "Lax",
      secure: conn.scheme == :https
    )
  end

  defp target_origin(target_url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(target_url)
    %URI{scheme: scheme, host: host, port: port} |> URI.to_string()
  end

  defp encode_source_url_cookie(raw_url) do
    Base.url_encode64(raw_url, padding: false)
  end

  defp put_proxy_response_headers(conn, target_url, headers) do
    Enum.reduce(headers, conn, fn {name, value}, conn ->
      put_proxy_response_header(conn, target_url, String.downcase(name), List.wrap(value))
    end)
  end

  defp put_proxy_response_header(conn, target_url, name, values) do
    case MapSet.member?(@response_headers_blocklist, name) do
      true -> conn
      false -> put_allowed_response_header(conn, target_url, name, values)
    end
  end

  defp put_allowed_response_header(conn, target_url, "location", [location | _values]) do
    put_resp_header(conn, "location", proxied_location(target_url, location))
  end

  defp put_allowed_response_header(conn, _target_url, name, values) do
    put_resp_header(conn, name, Enum.join(values, ", "))
  end

  defp proxied_location(target_url, location) do
    resolved_location = target_url |> URI.merge(location) |> URI.to_string()

    case TargetPolicy.validate_target_url(resolved_location) do
      :ok -> "/sandbox?" <> URI.encode_query(%{"url" => resolved_location}, :rfc3986)
      {:error, _reason} -> location
    end
  end

  defp response_body(%{method: "HEAD"}, _target_url, _response), do: ""

  defp response_body(conn, target_url, %Req.Response{body: body}) when is_binary(body) do
    body
    |> rewrite_runtime_response(conn)
    |> DevServerPolicy.rewrite_client_websocket_host(target_url, conn)
  end

  defp response_body(_conn, _target_url, %Req.Response{body: nil}), do: ""
  defp response_body(_conn, _target_url, %Req.Response{body: body}), do: body

  defp rewrite_runtime_response(body, conn) do
    case source_url(conn) do
      {:ok, raw_url} ->
        RuntimePolicy.rewrite_response_body(body, sandbox_proxy_url(conn, raw_url))

      {:error, :missing_url} ->
        body
    end
  end

  defp sandbox_proxy_url(conn, raw_url) do
    request_origin(conn) <> "/sandbox?" <> URI.encode_query(%{"url" => raw_url}, :rfc3986)
  end

  defp request_origin(conn) do
    scheme = Atom.to_string(conn.scheme)

    case default_port?(conn.scheme, conn.port) do
      true -> scheme <> "://" <> conn.host
      false -> scheme <> "://" <> conn.host <> ":" <> Integer.to_string(conn.port)
    end
  end

  defp default_port?(:http, 80), do: true
  defp default_port?(:https, 443), do: true
  defp default_port?(_scheme, _port), do: false

  defp send_preflight(conn) do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
    |> halt()
  end

  defp send_error(conn, status, message) do
    body = Jason.encode!(%{error: message})

    conn
    |> put_cors_headers()
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
    |> halt()
  end

  defp send_target_policy_error(conn, reason) do
    {status, message} = TargetPolicy.error_response(reason)
    send_error(conn, status, message)
  end

  defp send_bad_gateway(conn, reason) do
    Logger.warning("Sandbox proxy request failed: #{inspect(reason)}")
    send_error(conn, :bad_gateway, "Sandbox request failed")
  end

  defp put_cors_headers(conn) do
    conn
    |> put_resp_header("vary", "origin")
    |> put_resp_header("access-control-allow-origin", cors_origin(conn))
    |> put_resp_header(
      "access-control-allow-methods",
      "GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS"
    )
    |> put_resp_header("access-control-allow-headers", cors_request_headers(conn))
  end

  defp cors_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin] -> origin
      _ -> "*"
    end
  end

  defp cors_request_headers(conn) do
    case get_req_header(conn, "access-control-request-headers") do
      [headers] -> headers
      _ -> "content-type"
    end
  end

  defp req_options do
    Application.get_env(:frontman_server, :sandbox_proxy_req_options, [])
  end
end
