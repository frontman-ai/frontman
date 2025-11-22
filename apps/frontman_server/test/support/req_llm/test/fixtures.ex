defmodule ReqLLM.Test.Fixtures do
  @moduledoc """
  Fixture support for ReqLLM streaming tests.

  This module provides the interface that ReqLLM.Streaming expects
  for recording and replaying fixtures.

  ## Recording Fixtures

  Since ReqLLM's capture mechanism is test-only, we use a simpler approach:
  - First run: Make real API calls, manually capture responses
  - Subsequent runs: Replay from captured JSON files

  For now, tests will make real API calls until we implement proper capture.
  Use the TODO in the code to add capture logic when needed.
  """

  @doc """
  Returns the fixture path for capture (recording) if in record mode.
  Otherwise returns nil to indicate replay mode.

  This is called by ReqLLM.Streaming to determine if it should save fixtures.
  """
  def capture_path(_model, opts) do
    mode = System.get_env("REQ_LLM_FIXTURES_MODE") || "replay"
    fixture_path = Keyword.get(opts, :fixture_path)

    case mode do
      "record" when not is_nil(fixture_path) ->
        # Return the path so ReqLLM.StreamServer will save the fixture
        fixture_path

      _ ->
        # Don't capture in replay mode or if no path provided
        nil
    end
  end

  @doc """
  Returns the fixture path for replay if the file exists.
  Otherwise returns :no_fixture to trigger real API call.
  """
  def replay_path(_model, opts) do
    mode = System.get_env("REQ_LLM_FIXTURES_MODE") || "replay"
    fixture_path = Keyword.get(opts, :fixture_path)

    case mode do
      "record" ->
        # In record mode, don't replay - make real calls
        :no_fixture

      _ ->
        cond do
          is_nil(fixture_path) ->
            :no_fixture

          File.exists?(fixture_path) ->
            {:fixture, fixture_path}

          true ->
            IO.puts("""

            ⚠️  Fixture not found: #{fixture_path}

            To record this fixture, run:
              REQ_LLM_FIXTURES_MODE=record mix test

            For now, falling back to real API call...
            """)

            :no_fixture
        end
    end
  end
end
