defmodule Mix.Tasks.ActivationAudienceReport do
  @shortdoc "Report activation audience counts without provider calls"
  @moduledoc """
  Requires --cutoff and --as-of ISO-8601 UTC timestamps, with cutoff < as-of.
  Counts use current retained records, not a historical database snapshot.
  This task starts only the repository, not application workers.
  """
  use Boundary, classify_to: FrontmanServer.Accounts
  use Mix.Task

  alias FrontmanServer.Accounts
  alias FrontmanServer.Repo

  @impl Mix.Task
  def run(args) do
    {options, [], []} = OptionParser.parse(args, strict: [cutoff: :string, as_of: :string])
    cutoff = utc!(options[:cutoff])
    as_of = utc!(options[:as_of])
    if DateTime.compare(cutoff, as_of) != :lt, do: Mix.raise("CUTOFF must precede AS_OF")

    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    cutoff
    |> Accounts.activation_audience_report(as_of)
    |> Jason.encode!()
    |> Mix.shell().info()
  end

  defp utc!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, 0} -> timestamp
      _ -> Mix.raise("CUTOFF and AS_OF must be explicit ISO-8601 UTC timestamps")
    end
  end

  defp utc!(nil), do: Mix.raise("CUTOFF and AS_OF are required")
end
