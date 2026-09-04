# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.IntegrationsController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Frameworks

  require Logger

  @cache_ttl_ms :timer.minutes(30)

  def latest_versions(conn, _params) do
    versions = get_cached_versions()
    json(conn, %{versions: versions})
  end

  defp get_cached_versions do
    case :persistent_term.get({__MODULE__, :cache}, nil) do
      {versions, fetched_at} when is_map(versions) ->
        if System.monotonic_time(:millisecond) - fetched_at < @cache_ttl_ms do
          versions
        else
          do_fetch_and_cache()
        end

      _ ->
        do_fetch_and_cache()
    end
  end

  defp do_fetch_and_cache do
    versions =
      Frameworks.update_sources()
      |> Task.async_stream(&fetch_latest_version/1,
        timeout: :timer.seconds(10),
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {key, version}}, acc -> Map.put(acc, key, version)
        {:exit, _reason}, acc -> acc
      end)

    has_valid_version = Enum.any?(versions, fn {_key, version} -> version != nil end)

    if has_valid_version do
      :persistent_term.put({__MODULE__, :cache}, {versions, System.monotonic_time(:millisecond)})
    end

    versions
  end

  defp fetch_latest_version({:npm, package}) do
    url = "https://registry.npmjs.org/#{package}/latest"

    case Req.get(url, registry_request_options()) do
      {:ok, %Req.Response{status: 200, body: %{"version" => version}}} ->
        {package, version}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("npm registry returned #{status} for #{package}: #{inspect(body)}")
        {package, nil}

      {:error, reason} ->
        Logger.warning("Failed to fetch npm version for #{package}: #{inspect(reason)}")
        {package, nil}
    end
  end

  defp fetch_latest_version({:wordpress, plugin}) do
    url = "https://api.wordpress.org/plugins/info/1.2/"
    key = "wordpress:#{plugin}"

    params = [
      {"action", "plugin_information"},
      {"request[slug]", plugin},
      {"request[fields][sections]", "0"}
    ]

    case Req.get(url, [params: params] ++ registry_request_options()) do
      {:ok, %Req.Response{status: 200, body: %{"version" => version}}}
      when is_binary(version) and byte_size(version) > 0 ->
        {key, version}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("WordPress.org returned #{status} for #{plugin}: #{inspect(body)}")
        {key, nil}

      {:error, reason} ->
        Logger.warning("Failed to fetch WordPress version for #{plugin}: #{inspect(reason)}")
        {key, nil}
    end
  end

  defp registry_request_options do
    [headers: [{"accept", "application/json"}], receive_timeout: :timer.seconds(10)] ++
      (Application.get_env(:frontman_server, __MODULE__, [])[:registry_request_options] || [])
  end
end
