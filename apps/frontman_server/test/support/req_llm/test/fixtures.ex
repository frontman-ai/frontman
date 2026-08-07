defmodule ReqLLM.Test.Fixtures do
  require Logger

  def capture_path(_model, opts) do
    fixture_path = Keyword.get(opts, :fixture_path)

    case {mode(), fixture_path} do
      {:record, path} when is_binary(path) ->
        path

      _ ->
        nil
    end
  end

  def replay_path(_model, opts) do
    fixture_path = Keyword.get(opts, :fixture_path)

    case {mode(), fixture_path} do
      {:record, _} ->
        :no_fixture

      {_, nil} ->
        :no_fixture

      {:replay, path} when is_binary(path) ->
        if File.exists?(path) do
          {:fixture, path}
        else
          Logger.warning("""
          Fixture not found: #{path}

          To record this fixture, run:
            REQ_LLM_FIXTURES_MODE=record mix test --only integration

          Falling back to real API call...
          """)

          :no_fixture
        end
    end
  end

  def mode do
    case System.get_env("REQ_LLM_FIXTURES_MODE") do
      "record" -> :record
      _ -> :replay
    end
  end

  def recording?, do: mode() == :record

  def replaying?, do: mode() == :replay
end
