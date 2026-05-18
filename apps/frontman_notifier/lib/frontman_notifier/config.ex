defmodule FrontmanNotifier.Config do
  @moduledoc """
  Runtime configuration read from environment variables.
  """

  @github_api_base_url "https://api.github.com"
  @github_repository "frontman-ai/frontman"
  @check_interval_ms 60 * 60 * 1_000
  @task_idle_minutes 30
  @task_lookback_hours 24
  @task_max_per_run 20
  @github_stargazer_pages 3

  @spec github_api_base_url() :: String.t()
  def github_api_base_url do
    env("FRONTMAN_NOTIFIER_GITHUB_API_BASE_URL", @github_api_base_url)
  end

  @spec github_repository() :: String.t()
  def github_repository do
    env("FRONTMAN_NOTIFIER_GITHUB_REPOSITORY", @github_repository)
  end

  @spec github_token() :: String.t() | nil
  def github_token do
    env("GITHUB_TOKEN", nil)
  end

  @spec discord_stargazers_webhook_url() :: String.t() | nil
  def discord_stargazers_webhook_url do
    env("DISCORD_STARGAZERS_WEBHOOK_URL", nil)
  end

  @spec discord_task_summaries_webhook_url() :: String.t() | nil
  def discord_task_summaries_webhook_url do
    env("DISCORD_TASK_SUMMARIES_WEBHOOK_URL", nil)
  end

  @spec database_url!() :: String.t()
  def database_url! do
    case env("FRONTMAN_NOTIFIER_DATABASE_URL", nil) || env("DATABASE_URL", nil) do
      value when is_binary(value) -> value
      nil -> raise "DATABASE_URL or FRONTMAN_NOTIFIER_DATABASE_URL is required"
    end
  end

  @spec database_ssl?() :: boolean()
  def database_ssl? do
    case env("FRONTMAN_NOTIFIER_DATABASE_SSL", nil) || env("DATABASE_SSL", "false") do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      value -> raise "Invalid boolean for database SSL: #{inspect(value)}"
    end
  end

  @spec state_dir() :: String.t()
  def state_dir do
    env("FRONTMAN_NOTIFIER_STATE_DIR", "./var/frontman_notifier")
  end

  @spec check_interval_ms() :: pos_integer()
  def check_interval_ms do
    positive_int_env("FRONTMAN_NOTIFIER_CHECK_INTERVAL_MS", @check_interval_ms)
  end

  @spec task_idle_minutes() :: pos_integer()
  def task_idle_minutes do
    positive_int_env("FRONTMAN_NOTIFIER_TASK_IDLE_MINUTES", @task_idle_minutes)
  end

  @spec task_lookback_hours() :: pos_integer()
  def task_lookback_hours do
    positive_int_env("FRONTMAN_NOTIFIER_TASK_LOOKBACK_HOURS", @task_lookback_hours)
  end

  @spec task_max_per_run() :: pos_integer()
  def task_max_per_run do
    positive_int_env("FRONTMAN_NOTIFIER_TASK_MAX_PER_RUN", @task_max_per_run)
  end

  @spec github_stargazer_pages() :: pos_integer()
  def github_stargazer_pages do
    positive_int_env("FRONTMAN_NOTIFIER_GITHUB_STARGAZER_PAGES", @github_stargazer_pages)
  end

  defp env(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> value
    end
  end

  defp positive_int_env(name, default) do
    case env(name, nil) do
      nil -> default
      value -> parse_positive_int(name, value)
    end
  end

  defp parse_positive_int(name, value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> raise "Invalid positive integer for #{name}: #{inspect(value)}"
    end
  end
end
