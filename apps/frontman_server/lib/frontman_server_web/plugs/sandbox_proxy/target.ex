# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SandboxProxy.Target do
  @moduledoc false

  import Plug.Conn, only: [fetch_cookies: 1, get_req_header: 2, put_resp_cookie: 4]

  # Preserve RFC 3986 pchar reserved characters that are legal inside one path
  # segment. Dev servers use these characters as path syntax, e.g. Vite routes
  # like /@fs and scoped packages like /node_modules/@scope/pkg. Encoding them
  # to %40/%3A/etc. changes upstream routing, while / remains encoded by being
  # represented as the segment separator when we join path_info below.
  @path_segment_reserved_chars ~c"!$&'()*+,;=:@"
  @source_url_cookie "_frontman_sandbox_source_url"
  @source_url_cookie_max_age_seconds 3_600

  def url(raw_url, [], query_params) do
    raw_url
    |> URI.parse()
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  def url(raw_url, proxied_path, query_params) do
    raw_url
    |> URI.parse()
    |> put_proxied_path(proxied_path)
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  def url_for_path(raw_url, proxied_path, query_params) do
    raw_url
    |> URI.parse()
    |> put_request_path(proxied_path)
    |> put_merged_query(query_params, :drop_proxy_url)
    |> then(&{:ok, URI.to_string(&1)})
  end

  def url_for_referred_path(raw_url, proxied_path, query_string) do
    raw_url
    |> URI.parse()
    |> put_request_path(proxied_path)
    |> put_raw_query(query_string)
    |> then(&{:ok, URI.to_string(&1)})
  end

  def websocket_url(raw_url, proxied_path, query_string) do
    raw_url
    |> origin()
    |> URI.parse()
    |> put_request_path(proxied_path)
    |> put_raw_query(query_string)
    |> websocket_url_string()
  end

  def path_from_request(conn, drop_segments) do
    conn.path_info
    |> Enum.drop(drop_segments)
    |> maybe_keep_trailing_slash(conn.request_path)
  end

  def source_url(%{query_params: %{"url" => raw_url}}) when is_binary(raw_url) do
    {:ok, raw_url}
  end

  def source_url(conn), do: source_url_from_referer(conn)

  def source_url_from_referer(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] -> source_url_from_referer_url(referer)
      _ -> {:error, :missing_url}
    end
  end

  def source_url_from_cookie(conn) do
    cookies = fetch_cookies(conn).req_cookies

    case Map.fetch(cookies, @source_url_cookie) do
      {:ok, encoded_url} -> decode_source_url_cookie(encoded_url)
      :error -> {:error, :missing_url}
    end
  end

  def put_source_url_cookie(conn, target_url) do
    put_resp_cookie(
      conn,
      @source_url_cookie,
      target_url |> origin() |> encode_source_url_cookie(),
      http_only: true,
      max_age: @source_url_cookie_max_age_seconds,
      same_site: "Lax",
      secure: conn.scheme == :https
    )
  end

  def sandbox_proxy_url(conn, raw_url) do
    request_origin(conn) <> "/sandbox?" <> URI.encode_query(%{"url" => raw_url}, :rfc3986)
  end

  def proxied_location(target_url, location, validate_url) do
    resolved_location = target_url |> URI.merge(location) |> URI.to_string()

    case validate_url.(resolved_location) do
      :ok -> "/sandbox?" <> URI.encode_query(%{"url" => resolved_location}, :rfc3986)
      {:error, _reason} -> location
    end
  end

  defp websocket_url_string(%URI{scheme: "https"} = uri) do
    {:ok, URI.to_string(%{uri | scheme: "wss"})}
  end

  defp websocket_url_string(%URI{scheme: "http"} = uri) do
    {:ok, URI.to_string(%{uri | scheme: "ws"})}
  end

  defp websocket_url_string(%URI{}), do: {:error, :unsupported_scheme}

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

  defp origin(target_url) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(target_url)
    %URI{scheme: scheme, host: host, port: port} |> URI.to_string()
  end

  defp encode_source_url_cookie(raw_url) do
    Base.url_encode64(raw_url, padding: false)
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
end
