# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PublicURL do
  @moduledoc "Validates and pins HTTP requests to public addresses."

  @ssrf_error "Requests to private/internal addresses are not allowed. " <>
                "For current app pages or local development URLs, use the available browser " <>
                "or framework-specific page inspection tools instead."

  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(url) when is_binary(url) do
    case resolve(url) do
      {:ok, _resolved} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  @doc false
  def attach(request) do
    Req.Request.append_request_steps(request, public_url: &protect_req/1)
  end

  @doc false
  def protect_req(%Req.Request{adapter: Req.Plug} = request), do: request

  def protect_req(%Req.Request{} = request) do
    case Req.Request.get_private(request, :public_url_pinned, false) do
      true ->
        request

      false ->
        case resolve(request.url) do
          {:ok, {host, address}} -> pin_req(request, host, address)
          {:error, message} -> {request, ArgumentError.exception(message)}
        end
    end
  end

  @doc false
  def protect_finch(%Finch.Request{} = request, finch_name) do
    url = %URI{scheme: Atom.to_string(request.scheme), host: request.host, port: request.port}

    case resolve(url) do
      {:ok, {host, address}} -> pin_finch(request, finch_name, host, address)
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp resolve(url) when is_binary(url) do
    with :ok <- validate_scheme(url) do
      resolve(URI.parse(url))
    end
  end

  defp resolve(%URI{scheme: scheme, host: host})
       when scheme in ["http", "https"] and is_binary(host) and byte_size(host) > 0 do
    host = String.downcase(host)

    with :ok <- validate_host(host),
         {:ok, address} <- resolve_address(host) do
      {:ok, {host, address}}
    end
  end

  defp resolve(%URI{host: host}) when not is_binary(host) or byte_size(host) == 0,
    do: {:error, "Could not parse host from URL"}

  defp resolve(%URI{}), do: {:error, "URL must start with http:// or https://"}

  defp validate_scheme("http://" <> _), do: :ok
  defp validate_scheme("https://" <> _), do: :ok
  defp validate_scheme(_), do: {:error, "URL must start with http:// or https://"}

  defp validate_host("localhost"), do: ssrf_error()
  defp validate_host("localhost" <> _), do: ssrf_error()

  defp validate_host(host) do
    case String.ends_with?(host, [".local", ".internal", ".localhost"]) do
      true -> ssrf_error()
      false -> :ok
    end
  end

  defp resolve_address(host) do
    host_charlist = String.to_charlist(host)

    case :inet.parse_address(host_charlist) do
      {:ok, address} -> public_address([address])
      {:error, :einval} -> resolve_hostname(host_charlist)
    end
  end

  defp resolve_hostname(host) do
    addresses =
      Enum.flat_map([:inet, :inet6], fn family ->
        case :inet.getaddrs(host, family) do
          {:ok, addresses} -> addresses
          {:error, _reason} -> []
        end
      end)

    case addresses do
      [] -> {:error, "Could not resolve hostname"}
      addresses -> public_address(addresses)
    end
  end

  defp public_address(addresses) do
    case Enum.any?(addresses, &private_address?/1) do
      true -> ssrf_error()
      false -> {:ok, hd(addresses)}
    end
  end

  defp pin_req(request, host, address) do
    finch_options = normalize_finch_options(request.options[:finch])
    finch_name = Keyword.fetch!(finch_options, :name)

    {address, pool_tag} =
      start_pool(finch_name, request.url.scheme, request.url.port, host, address)

    finch_options = Keyword.put(finch_options, :pool_tag, pool_tag)

    request
    |> Req.Request.put_header("host", authority(host, request.url.scheme, request.url.port))
    |> Req.Request.put_private(:public_url_pinned, true)
    |> Map.update!(:url, &%{&1 | host: address})
    |> Map.update!(:options, fn options ->
      options
      |> Map.delete(:connect_options)
      |> Map.put(:finch, finch_options)
      |> Map.put(:redirect, false)
    end)
  end

  defp pin_finch(request, finch_name, host, address) do
    {address, pool_tag} = start_pool(finch_name, request.scheme, request.port, host, address)

    headers =
      request.headers
      |> Enum.reject(fn {name, _value} -> String.downcase(name) == "host" end)
      |> List.insert_at(0, {"host", authority(host, request.scheme, request.port)})

    %{request | host: address, headers: headers, pool_tag: pool_tag}
  end

  defp start_pool(finch_name, scheme, port, host, address) do
    inet6? = tuple_size(address) == 8
    address = address_string(address)
    pool_tag = {:public_url, host}
    pool = %Finch.Pool{scheme: normalize_scheme(scheme), host: address, port: port, tag: pool_tag}
    conn_opts = [hostname: host, transport_opts: [inet6: inet6?]]

    :ok =
      Finch.start_pool(finch_name, pool,
        protocols: [:http1],
        conn_opts: conn_opts,
        pool_max_idle_time: 60_000
      )

    {address, pool_tag}
  end

  defp normalize_finch_options(nil), do: [name: ReqLLM.Application.finch_name()]
  defp normalize_finch_options(name) when is_atom(name), do: [name: name]

  defp normalize_finch_options(options) when is_list(options) do
    Keyword.put_new(options, :name, ReqLLM.Application.finch_name())
  end

  defp normalize_scheme("http"), do: :http
  defp normalize_scheme("https"), do: :https
  defp normalize_scheme(scheme), do: scheme

  defp authority(host, scheme, port) do
    host = if String.contains?(host, ":"), do: "[#{host}]", else: host

    case {scheme, port} do
      {scheme, port} when scheme in ["http", :http] and port in [nil, 80] -> host
      {scheme, port} when scheme in ["https", :https] and port in [nil, 443] -> host
      _other -> "#{host}:#{port}"
    end
  end

  defp address_string(address), do: address |> :inet.ntoa() |> to_string()

  defp ssrf_error, do: {:error, @ssrf_error}

  defp private_address?({0, _, _, _}), do: true
  defp private_address?({10, _, _, _}), do: true
  defp private_address?({127, _, _, _}), do: true
  defp private_address?({100, second, _, _}) when second in 64..127, do: true
  defp private_address?({169, 254, _, _}), do: true
  defp private_address?({172, second, _, _}) when second in 16..31, do: true
  defp private_address?({192, 0, 0, _}), do: true
  defp private_address?({192, 0, 2, _}), do: true
  defp private_address?({192, 88, 99, _}), do: true
  defp private_address?({192, 168, _, _}), do: true
  defp private_address?({198, second, _, _}) when second in 18..19, do: true
  defp private_address?({198, 51, 100, _}), do: true
  defp private_address?({203, 0, 113, _}), do: true
  defp private_address?({first, _, _, _}) when first in 224..255, do: true

  defp private_address?({0x2001, second, _, _, _, _, _, _}) when second <= 0x1FF, do: true
  defp private_address?({0x2001, 0xDB8, _, _, _, _, _, _}), do: true
  defp private_address?({0x2002, _, _, _, _, _, _, _}), do: true
  defp private_address?({0x3FFF, second, _, _, _, _, _, _}) when second <= 0xFFF, do: true
  defp private_address?({first, _, _, _, _, _, _, _}) when first not in 0x2000..0x3FFF, do: true
  defp private_address?(_address), do: false
end
