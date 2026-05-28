# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxy.Daytona do
  @moduledoc false

  @default_target_hosts [
    "daytonaproxy01.eu",
    "daytona.work",
    "proxy.daytona.work"
  ]
  @default_target_schemes ["https"]
  @skip_preview_warning_header {"x-daytona-skip-preview-warning", "true"}

  def control_request(%{
        path_info: ["accept-daytona-preview-warning"],
        query_params: %{"redirect" => redirect_url}
      })
      when is_binary(redirect_url) do
    case preview_warning_redirect_path(redirect_url) do
      {:ok, redirect_path} -> {:redirect, redirect_path}
      {:error, _reason} -> {:error, :bad_request, invalid_preview_redirect_message()}
    end
  end

  def control_request(%{path_info: ["accept-daytona-preview-warning"]}) do
    {:error, :bad_request, missing_preview_redirect_message()}
  end

  def control_request(_conn), do: :not_handled

  def validate_target_url(target_url) when is_binary(target_url) do
    %URI{scheme: scheme, host: host} = URI.parse(target_url)
    validate_parsed_url(scheme, host)
  end

  def validate_target_url(_target_url), do: {:error, :invalid_url}

  def put_request_headers(headers) do
    put_skip_preview_warning_header(headers)
  end

  def error_response(:invalid_url), do: {:bad_request, "Invalid Daytona URL"}
  def error_response(:unsupported_host), do: {:bad_request, "Unsupported Daytona host"}
  def error_response(:unsupported_scheme), do: {:bad_request, "Unsupported URL scheme"}

  defp preview_warning_redirect_path(redirect_url) when is_binary(redirect_url) do
    case validate_target_url(redirect_url) do
      :ok -> {:ok, "/sandbox?" <> URI.encode_query(%{"url" => redirect_url})}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_skip_preview_warning_header(headers) do
    {name, _value} = @skip_preview_warning_header

    case List.keymember?(headers, name, 0) do
      true -> headers
      false -> [@skip_preview_warning_header | headers]
    end
  end

  defp invalid_preview_redirect_message do
    "Invalid Daytona redirect URL"
  end

  defp missing_preview_redirect_message do
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
    Enum.any?(target_hosts(), &host_matches_suffix?(normalized_host, &1))
  end

  defp host_matches_suffix?(host, suffix) do
    case host do
      ^suffix -> true
      _ -> String.ends_with?(host, "." <> suffix)
    end
  end

  defp target_hosts do
    config() |> Keyword.get(:target_hosts, @default_target_hosts) |> Enum.map(&String.downcase/1)
  end

  defp allowed_schemes do
    config() |> Keyword.get(:target_schemes, @default_target_schemes)
  end

  defp config do
    :frontman_server
    |> Application.get_env(:playgithub, [])
    |> Keyword.get(:sandbox_proxy, [])
  end
end
