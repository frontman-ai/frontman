defmodule FrontmanServerWeb.IntegrationsController do
  use FrontmanServerWeb, :controller

  require Logger

  @packages ~w(@frontman-ai/vite @frontman-ai/nextjs @frontman-ai/astro)

  # Simple in-memory cache: {versions_map, fetched_at_unix}
  @cache_ttl_ms :timer.minutes(30)

  def latest_versions(conn, _params) do
    versions = get_cached_versions()
    json(conn, %{versions: versions})
  end

  # -- private --

  defp get_cached_versions do
    case :persistent_term.get({__MODULE__, :cache}, nil) do
      {versions, fetched_at} when is_map(versions) ->
        if System.monotonic_time(:millisecond) - fetched_at < @cache_ttl_ms do
          versions
        else
          fetch_and_cache()
        end

      _ ->
        fetch_and_cache()
    end
  end

  defp fetch_and_cache do
    # Double-check: another request may have refreshed the cache while we waited
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
      @packages
      |> Task.async_stream(&fetch_latest_version/1,
        timeout: :timer.seconds(10),
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {pkg, version}}, acc -> Map.put(acc, pkg, version)
        {:exit, _reason}, acc -> acc
      end)

    # Only cache when at least one package resolved successfully.
    # On total failure (all nil / empty map), skip caching so the next
    # request retries immediately instead of serving stale nils for 30 min.
    has_valid_version = Enum.any?(versions, fn {_pkg, v} -> v != nil end)

    if has_valid_version do
      :persistent_term.put({__MODULE__, :cache}, {versions, System.monotonic_time(:millisecond)})
    end

    versions
  end

  defp fetch_latest_version(package) do
    url = "https://registry.npmjs.org/#{package}/latest"

    case Req.get(url, headers: [{"accept", "application/json"}]) do
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
end
