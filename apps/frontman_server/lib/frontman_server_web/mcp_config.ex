# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.McpConfig do
  @moduledoc "Validates configured MCP resource and authorization server identifiers."

  def fetch(config \\ Application.get_env(:frontman_server, :mcp_discovery)) do
    config = config || []

    with resource when is_binary(resource) <- config[:resource],
         issuer when is_binary(issuer) <- config[:issuer],
         {:ok, %URI{path: "/mcp"}} <- valid_url(resource),
         {:ok, _} <- valid_url(issuer) do
      {:ok, resource, issuer}
    else
      _ -> {:error, :invalid_configuration}
    end
  end

  defp valid_url(url) do
    with false <- Regex.match?(~r/%(?![0-9A-Fa-f]{2})/, url),
         {:ok,
          %URI{scheme: "https", host: host, port: port, userinfo: nil, query: nil, fragment: nil} =
            uri}
         when is_binary(host) and byte_size(host) > 0 and port in 1..65535 <- URI.new(url),
         false <- String.ends_with?(URI.parse(url).authority, ":") do
      {:ok, uri}
    else
      _ -> :error
    end
  end
end
