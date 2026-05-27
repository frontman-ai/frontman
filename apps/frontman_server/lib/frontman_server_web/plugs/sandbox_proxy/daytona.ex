# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SandboxProxy.Daytona do
  @moduledoc false

  @default_allowed_hosts [
    "daytonaproxy01.eu",
    "daytona.work",
    "proxy.daytona.work"
  ]
  @default_allowed_schemes ["https"]
  @skip_preview_warning_header {"x-daytona-skip-preview-warning", "true"}

  def validate_target_url(target_url) do
    case URI.parse(target_url) do
      %URI{scheme: scheme, host: host} ->
        validate_parsed_url(scheme, host)

      _ ->
        {:error, :invalid_url}
    end
  end

  def preview_warning_redirect_path(redirect_url) when is_binary(redirect_url) do
    case validate_target_url(redirect_url) do
      :ok -> {:ok, "/sandbox?" <> URI.encode_query(%{"url" => redirect_url})}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_skip_preview_warning_header(headers) do
    {name, _value} = @skip_preview_warning_header

    case List.keymember?(headers, name, 0) do
      true -> headers
      false -> [@skip_preview_warning_header | headers]
    end
  end

  def error_response(:invalid_url), do: {:bad_request, "Invalid Daytona URL"}
  def error_response(:unsupported_host), do: {:bad_request, "Unsupported Daytona host"}
  def error_response(:unsupported_scheme), do: {:bad_request, "Unsupported URL scheme"}

  def invalid_preview_redirect_message do
    "Invalid Daytona redirect URL"
  end

  def missing_preview_redirect_message do
    "Missing redirect query parameter"
  end

  defp validate_parsed_url(scheme, host) when is_binary(scheme) do
    case is_binary(host) do
      true ->
        case validate_scheme(scheme) do
          :ok -> validate_host(host)
          {:error, reason} -> {:error, reason}
        end

      false ->
        {:error, :invalid_url}
    end
  end

  defp validate_parsed_url(_scheme, _host), do: {:error, :invalid_url}

  defp validate_scheme(scheme) do
    case scheme in allowed_schemes() do
      true -> :ok
      false -> {:error, :unsupported_scheme}
    end
  end

  defp validate_host(host) do
    case allowed_host?(host) do
      true -> :ok
      false -> {:error, :unsupported_host}
    end
  end

  defp allowed_host?(host) when is_binary(host) do
    normalized_host = String.downcase(host)
    Enum.any?(allowed_hosts(), &host_matches_suffix?(normalized_host, &1))
  end

  defp host_matches_suffix?(host, suffix) do
    case host do
      ^suffix -> true
      _ -> String.ends_with?(host, "." <> suffix)
    end
  end

  defp allowed_hosts do
    :frontman_server
    |> Application.get_env(:sandbox_proxy_allowed_hosts, @default_allowed_hosts)
    |> Enum.map(&String.downcase/1)
  end

  defp allowed_schemes do
    Application.get_env(
      :frontman_server,
      :sandbox_proxy_allowed_schemes,
      @default_allowed_schemes
    )
  end
end
