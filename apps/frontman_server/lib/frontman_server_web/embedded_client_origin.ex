# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.EmbeddedClientOrigin do
  @moduledoc """
  Normalizes and validates browser origins allowed to request embedded client tokens.
  """

  @localhost_hosts ["localhost", "127.0.0.1", "::1"]

  def normalize(origin) when is_binary(origin) do
    origin
    |> URI.parse()
    |> normalize_uri()
  end

  def normalize(_origin), do: {:error, :invalid_origin}

  defp normalize_uri(%URI{} = uri) do
    with :ok <- validate_scheme(uri),
         :ok <- validate_host(uri),
         :ok <- validate_no_extra_parts(uri) do
      {:ok, origin_string(uri)}
    else
      {:error, :invalid_origin} -> {:error, :invalid_origin}
    end
  end

  defp validate_scheme(%URI{scheme: "https"}), do: :ok

  defp validate_scheme(%URI{scheme: "http", host: host}) when host in @localhost_hosts, do: :ok

  defp validate_scheme(_uri), do: {:error, :invalid_origin}

  defp validate_host(%URI{host: host}) when is_binary(host) and byte_size(host) > 0, do: :ok

  defp validate_host(_uri), do: {:error, :invalid_origin}

  defp validate_no_extra_parts(%URI{} = uri) do
    case {uri.userinfo, uri.path, uri.query, uri.fragment} do
      {nil, path, nil, nil} when path in [nil, ""] -> :ok
      _ -> {:error, :invalid_origin}
    end
  end

  defp origin_string(%URI{scheme: scheme, host: host, port: port}) do
    normalized_host = host |> String.downcase() |> bracket_ipv6_host()

    case default_port?(scheme, port) do
      true -> "#{scheme}://#{normalized_host}"
      false -> "#{scheme}://#{normalized_host}:#{port}"
    end
  end

  defp bracket_ipv6_host(host) do
    case String.contains?(host, ":") do
      true -> "[#{host}]"
      false -> host
    end
  end

  defp default_port?("http", 80), do: true
  defp default_port?("https", 443), do: true
  defp default_port?(_scheme, nil), do: true
  defp default_port?(_scheme, _port), do: false
end
