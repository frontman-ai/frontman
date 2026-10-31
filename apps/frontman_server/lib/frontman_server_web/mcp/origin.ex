defmodule FrontmanServerWeb.MCP.Origin do
  @moduledoc "Checks configured MCP URLs and compares serialized browser origins."

  def resource(resource) when is_binary(resource) do
    with true <- String.valid?(resource),
         {:ok, %URI{scheme: "https", host: host, port: port, path: "/mcp"} = uri}
         when is_binary(host) and byte_size(host) > 0 and port in 1..65_535 <-
           URI.new(resource),
         {nil, nil, nil} <- {uri.userinfo, uri.query, uri.fragment},
         ^resource <- :uri_string.normalize(resource),
         true <- canonical_host?(host) do
      {:ok, String.replace_suffix(resource, "/mcp", "")}
    else
      _ -> :error
    end
  end

  def resource(_resource), do: :error

  def issuer(issuer) when is_binary(issuer) do
    with true <- String.valid?(issuer),
         {:ok, %URI{scheme: "https", host: host, port: port} = uri}
         when is_binary(host) and byte_size(host) > 0 and port in 1..65_535 <-
           URI.new(issuer),
         {nil, nil, nil} <- {uri.userinfo, uri.query, uri.fragment},
         false <- String.contains?(host, "%"),
         false <- String.ends_with?(URI.parse(issuer).authority, ":"),
         true <- is_binary(:uri_string.normalize(issuer)),
         true <- is_nil(uri.path) or String.valid?(URI.decode(uri.path)) do
      :ok
    else
      _ -> :error
    end
  end

  def issuer(_issuer), do: :error

  def allowed?(expected, origin), do: origin == expected

  defp canonical_host?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} -> host == List.to_string(:inet.ntoa(address))
      {:error, :einval} -> not String.contains?(host, "%")
    end
  end
end
