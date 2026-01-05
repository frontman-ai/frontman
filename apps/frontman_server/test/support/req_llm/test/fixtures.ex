defmodule ReqLLM.Test.Fixtures do
  @moduledoc """
  Fixture support for ReqLLM streaming tests.

  This module provides the interface that ReqLLM.Streaming expects
  for recording and replaying fixtures.

  ## Modes

  Controlled by `REQ_LLM_FIXTURES_MODE` environment variable:
  - `"replay"` (default) - Load from cached fixtures, skip API calls
  - `"record"` - Make real API calls and save responses

  ## Usage

  Pass fixture options to ReqLLM calls:

      # Explicit path
      ReqLLM.stream_text(model, messages, fixture_path: "path/to/fixture.json")

      # Or use LLMIntegrationCase for automatic path generation
  """

  require Logger

  @doc """
  Returns the fixture path for capture (recording) if in record mode.
  Otherwise returns nil to indicate replay mode.

  Called by ReqLLM.Streaming to determine if it should save fixtures.
  """
  @spec capture_path(any(), keyword()) :: Path.t() | nil
  def capture_path(_model, opts) do
    fixture_path = Keyword.get(opts, :fixture_path)

    case {mode(), fixture_path} do
      {:record, path} when is_binary(path) ->
        path

      _ ->
        nil
    end
  end

  @doc """
  Returns the fixture path for replay if the file exists.
  Otherwise returns :no_fixture to trigger real API call.

  Called by ReqLLM.Streaming.FinchClient to check for fixtures.
  """
  @spec replay_path(any(), keyword()) :: {:fixture, Path.t()} | :no_fixture
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

  @doc """
  Returns the current fixture mode.
  """
  @spec mode() :: :record | :replay
  def mode do
    case System.get_env("REQ_LLM_FIXTURES_MODE") do
      "record" -> :record
      _ -> :replay
    end
  end

  @doc """
  Check if currently in record mode.
  """
  @spec recording?() :: boolean()
  def recording?, do: mode() == :record

  @doc """
  Check if currently in replay mode.
  """
  @spec replaying?() :: boolean()
  def replaying?, do: mode() == :replay
end
