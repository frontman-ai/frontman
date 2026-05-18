defmodule FrontmanNotifier do
  @moduledoc """
  Hourly production notifier for GitHub stargazers and completed Frontman tasks.
  """

  require Logger

  alias FrontmanNotifier.Stargazers
  alias FrontmanNotifier.TaskSummaries

  @spec run_once() :: %{
          stargazers: {:ok, non_neg_integer()} | {:error, term()},
          tasks: {:ok, non_neg_integer()} | {:error, term()}
        }
  def run_once do
    %{
      stargazers: run_job(:stargazers, &Stargazers.check/0),
      tasks: run_job(:tasks, &TaskSummaries.check/0)
    }
  end

  defp run_job(name, callback) when is_atom(name) and is_function(callback, 0) do
    case callback.() do
      {:ok, count} ->
        Logger.info("#{name} notifier posted #{count} Discord message(s)")
        {:ok, count}

      {:error, reason} ->
        Logger.error("#{name} notifier failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    exception ->
      stacktrace = __STACKTRACE__
      Logger.error(Exception.format(:error, exception, stacktrace))
      {:error, exception}
  end
end
