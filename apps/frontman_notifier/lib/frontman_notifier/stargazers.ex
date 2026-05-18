defmodule FrontmanNotifier.Stargazers do
  @moduledoc """
  Detects new repository stargazers and posts enriched Discord messages.
  """

  require Logger

  alias FrontmanNotifier.Config
  alias FrontmanNotifier.Discord
  alias FrontmanNotifier.GitHub
  alias FrontmanNotifier.State

  @namespace :stargazer
  @initialized_scope :stargazers
  @discord_color 0xF6C945

  @spec check() :: {:ok, non_neg_integer()} | {:error, term()}
  def check do
    case Config.discord_stargazers_webhook_url() do
      nil ->
        Logger.info("DISCORD_STARGAZERS_WEBHOOK_URL is not set; skipping stargazer notifier")
        {:ok, 0}

      webhook_url ->
        check(webhook_url)
    end
  end

  @spec build_embed(map(), map()) :: map()
  def build_embed(stargazer, profile) when is_map(stargazer) and is_map(profile) do
    login = profile["login"] || stargazer["login"]
    name = profile["name"] || login
    bio = blank_to_default(profile["bio"], "No bio provided.")

    %{
      title: "New GitHub star: #{name}",
      url: profile["html_url"] || stargazer["html_url"],
      color: @discord_color,
      description: truncate(bio, 700),
      thumbnail: %{url: profile["avatar_url"] || stargazer["avatar_url"]},
      fields:
        [
          field("GitHub", "[@#{login}](#{profile["html_url"] || stargazer["html_url"]})", true),
          field("Stats", profile_stats(profile), true),
          field("Account", account_summary(profile), true),
          optional_field("Company", profile["company"], true),
          optional_field("Location", profile["location"], true),
          optional_field("Blog", profile["blog"], true),
          optional_field("Starred at", stargazer["starred_at"], true)
        ]
        |> Enum.reject(&is_nil/1),
      footer: %{text: Config.github_repository()}
    }
  end

  defp check(webhook_url) do
    with {:ok, stargazers} <- GitHub.fetch_stargazers() do
      process_stargazers(webhook_url, stargazers)
    end
  end

  defp process_stargazers(webhook_url, stargazers) do
    case State.initialized?(@initialized_scope) do
      false ->
        Enum.each(stargazers, &mark_stargazer_seen/1)
        State.set_initialized(@initialized_scope)
        Logger.info("Recorded #{length(stargazers)} existing stargazer(s) as initial baseline")
        {:ok, 0}

      true ->
        post_new_stargazers(webhook_url, stargazers)
    end
  end

  defp post_new_stargazers(webhook_url, stargazers) do
    stargazers
    |> Enum.reject(&stargazer_seen?/1)
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, 0}, fn stargazer, {:ok, count} ->
      case post_stargazer(webhook_url, stargazer) do
        :ok -> {:cont, {:ok, count + 1}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp post_stargazer(webhook_url, %{"login" => login} = stargazer) do
    with {:ok, profile} <- GitHub.fetch_user(login),
         :ok <- Discord.post_embed(webhook_url, build_embed(stargazer, profile)) do
      mark_stargazer_seen(stargazer)
      :ok
    end
  end

  defp stargazer_seen?(%{"login" => login}) do
    State.seen?(@namespace, login)
  end

  defp mark_stargazer_seen(%{"login" => login}) do
    State.mark_seen(@namespace, login)
  end

  defp profile_stats(profile) do
    [
      "Repos: #{profile["public_repos"] || 0}",
      "Followers: #{profile["followers"] || 0}",
      "Following: #{profile["following"] || 0}",
      "Gists: #{profile["public_gists"] || 0}"
    ]
    |> Enum.join("\n")
  end

  defp account_summary(profile) do
    case profile["created_at"] do
      nil -> "Created: unknown"
      created_at -> "Created: #{created_at}"
    end
  end

  defp field(name, value, inline) do
    %{name: name, value: truncate(to_string(value), 1_000), inline: inline}
  end

  defp optional_field(_name, nil, _inline), do: nil
  defp optional_field(_name, "", _inline), do: nil
  defp optional_field(name, value, inline), do: field(name, value, inline)

  defp blank_to_default(nil, default), do: default
  defp blank_to_default("", default), do: default
  defp blank_to_default(value, _default), do: value

  defp truncate(value, max) when is_binary(value) and max > 0 do
    case String.length(value) > max do
      true -> String.slice(value, 0, max - 3) <> "..."
      false -> value
    end
  end
end
