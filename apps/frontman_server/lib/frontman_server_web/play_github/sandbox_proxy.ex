# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxy do
  @moduledoc """
  Proxies sandbox preview URLs through the Frontman API origin.

  The `/sandbox?url=...` query parameter path is temporary. Host-scoped
  PlayGithub requests resolve sandbox preview URLs through Daytona by id and
  port.
  """

  import Plug.Conn

  alias FrontmanServerWeb.PlayGithub.SandboxProxy.Daytona, as: TargetPolicy
  alias FrontmanServerWeb.PlayGithub.SandboxProxy.FrontmanRuntime, as: RuntimePolicy
  alias FrontmanServerWeb.PlayGithub.SandboxProxy.Target
  alias FrontmanServerWeb.PlayGithub.SandboxProxy.Vite, as: DevServerPolicy
  alias FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket

  require Logger

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

  def dispatch(conn) do
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

  defp proxy_request(conn) do
    case TargetPolicy.target_from_request_host(conn.host, playgithub_hosts()) do
      {:ok, %{url: raw_url, preview_token: preview_token}} ->
        proxy_host_target(conn, raw_url, preview_token)

      {:error, :missing_url} ->
        proxy_path_request(conn)

      {:error, :daytona_sandbox_not_found} ->
        send_error(conn, :not_found, "Sandbox not found")

      {:error, reason} ->
        send_bad_gateway(conn, reason)
    end
  end

  defp proxy_path_request(%{path_info: ["frontman" | _proxied_path]} = conn) do
    case conn.method do
      "OPTIONS" -> send_preflight(conn)
      _ -> proxy_frontman_path(conn, Target.path_from_request(conn, 0))
    end
  end

  defp proxy_path_request(%{path_info: ["sandbox" | _proxied_path]} = conn) do
    case conn.method do
      "OPTIONS" -> send_preflight(conn)
      _ -> proxy(conn, Target.path_from_request(conn, 1))
    end
  end

  defp proxy_path_request(conn) do
    case DevServerPolicy.websocket_request?(conn) do
      true -> proxy_websocket(conn)
      false -> proxy_referred_path(conn)
    end
  end

  defp proxy_host_target(conn, raw_url, preview_token) do
    case conn.method do
      "OPTIONS" ->
        send_preflight(conn)

      _ ->
        case DevServerPolicy.websocket_request?(conn) do
          true -> upgrade_websocket(conn, raw_url, preview_token)
          false -> proxy_host_path(conn, raw_url, preview_token)
        end
    end
  end

  defp proxy_host_path(conn, raw_url, preview_token) do
    run_proxy(
      conn,
      Target.url_for_referred_path(
        raw_url,
        Target.path_from_request(conn, 0),
        conn.query_string
      ),
      preview_token
    )
  end

  defp proxy_websocket(conn) do
    case source_url_for_websocket(conn) do
      {:ok, raw_url} -> upgrade_websocket(conn, raw_url, nil)
      {:error, :missing_url} -> send_error(conn, :bad_request, "Missing url query parameter")
    end
  end

  defp source_url_for_websocket(conn) do
    case Target.source_url(conn) do
      {:ok, raw_url} -> {:ok, raw_url}
      {:error, :missing_url} -> Target.source_url_from_cookie(conn)
    end
  end

  defp upgrade_websocket(conn, raw_url, preview_token) do
    with :ok <- TargetPolicy.validate_target_url(raw_url),
         {:ok, target_url} <- build_websocket_target_url(raw_url, conn) do
      conn
      |> put_resp_header("sec-websocket-protocol", DevServerPolicy.websocket_protocol())
      |> WebSockAdapter.upgrade(
        WebSocket,
        %{
          target_url: target_url,
          upstream_headers: proxy_websocket_request_headers(conn.req_headers, preview_token)
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
    Target.websocket_url(raw_url, Target.path_from_request(conn, 0), conn.query_string)
  end

  defp proxy(%{query_params: %{"url" => raw_url}} = conn, proxied_path)
       when is_binary(raw_url) do
    run_proxy(conn, Target.url(raw_url, proxied_path, conn.query_params), nil)
  end

  defp proxy(conn, _proxied_path) do
    send_error(conn, :bad_request, "Missing url query parameter")
  end

  defp proxy_frontman_path(conn, proxied_path) do
    case Target.source_url(conn) do
      {:ok, raw_url} ->
        run_proxy(conn, Target.url_for_path(raw_url, proxied_path, conn.query_params), nil)

      {:error, :missing_url} ->
        send_error(conn, :bad_request, "Missing url query parameter")
    end
  end

  defp proxy_referred_path(conn) do
    case source_url_for_referred_path(conn) do
      {:ok, raw_url} ->
        run_proxy(
          conn,
          Target.url_for_referred_path(
            raw_url,
            Target.path_from_request(conn, 0),
            conn.query_string
          ),
          nil
        )

      {:error, :missing_url} ->
        conn
    end
  end

  defp source_url_for_referred_path(conn) do
    case Target.source_url_from_referer(conn) do
      {:ok, raw_url} -> {:ok, raw_url}
      {:error, :missing_url} -> source_url_from_asset_cookie(conn)
    end
  end

  defp source_url_from_asset_cookie(conn) do
    case DevServerPolicy.dev_asset_path?(conn.path_info) do
      true -> Target.source_url_from_cookie(conn)
      false -> {:error, :missing_url}
    end
  end

  defp run_proxy(conn, {:ok, target_url}, preview_token) do
    with :ok <- TargetPolicy.validate_target_url(target_url),
         {:ok, body, conn} <- read_proxy_body(conn),
         {:ok, response} <- request_target(conn, target_url, body, preview_token) do
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

  defp request_target(conn, target_url, body, preview_token) do
    with {:ok, options} <- request_options(conn, target_url, body, preview_token) do
      options
      |> Req.request()
      |> normalize_response()
    end
  end

  defp request_options(conn, target_url, body, preview_token) do
    with {:ok, method} <- req_method(conn.method) do
      options =
        [
          method: method,
          url: target_url,
          headers: proxy_request_headers(conn.req_headers, preview_token),
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

  defp proxy_request_headers(headers, preview_token) do
    headers
    |> Enum.reject(fn {name, _value} -> MapSet.member?(@request_headers_blocklist, name) end)
    |> TargetPolicy.put_request_headers(preview_token)
  end

  defp proxy_websocket_request_headers(headers, preview_token) do
    headers
    |> Enum.reject(fn {name, _value} ->
      MapSet.member?(@websocket_request_headers_blocklist, name)
    end)
    |> DevServerPolicy.put_websocket_protocol_header()
    |> TargetPolicy.put_request_headers(preview_token)
  end

  defp normalize_response({:ok, %Req.Response{} = response}), do: {:ok, response}

  defp normalize_response({:error, %Req.TransportError{reason: :timeout}}) do
    {:error, :upstream_timeout}
  end

  defp normalize_response({:error, reason}), do: {:error, reason}

  defp send_proxy_response(conn, target_url, %Req.Response{} = response) do
    conn
    |> put_proxy_response_headers(target_url, response.headers)
    |> Target.put_source_url_cookie(target_url)
    |> put_cors_headers()
    |> send_resp(response.status, response_body(conn, target_url, response))
    |> halt()
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
    put_resp_header(conn, "location", proxied_location(conn, target_url, location))
  end

  defp put_allowed_response_header(conn, _target_url, name, values) do
    put_resp_header(conn, name, Enum.join(values, ", "))
  end

  defp proxied_location(target_url, location) do
    Target.proxied_location(target_url, location, &TargetPolicy.validate_target_url/1)
  end

  defp proxied_location(conn, target_url, location) do
    case TargetPolicy.host_scoped_request?(conn.host, playgithub_hosts()) do
      true ->
        Target.proxied_location_for_host(
          target_url,
          location,
          &TargetPolicy.validate_target_url/1
        )

      false ->
        proxied_location(target_url, location)
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
    case runtime_proxy_url(conn) do
      {:ok, proxy_url} ->
        RuntimePolicy.rewrite_response_body(body, proxy_url)

      {:error, :missing_url} ->
        body
    end
  end

  defp runtime_proxy_url(conn) do
    case TargetPolicy.host_scoped_request?(conn.host, playgithub_hosts()) do
      true ->
        {:ok, Target.request_origin(conn)}

      false ->
        case Target.source_url(conn) do
          {:ok, raw_url} -> {:ok, Target.sandbox_proxy_url(conn, raw_url)}
          {:error, :missing_url} -> {:error, :missing_url}
        end
    end
  end

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
    config() |> Keyword.get(:req_options, [])
  end

  defp config do
    :frontman_server
    |> Application.get_env(:playgithub, [])
    |> Keyword.get(:sandbox_proxy, [])
  end

  defp playgithub_hosts do
    :frontman_server
    |> Application.get_env(:playgithub, [])
    |> Keyword.get(:hosts, [])
    |> Enum.map(&String.downcase/1)
  end
end
