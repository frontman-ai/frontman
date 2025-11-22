defmodule ReqLLM.Step.Fixture.Backend do
  @moduledoc """
  Backend for saving streaming fixtures captured by ReqLLM.StreamServer.

  This module implements the fixture saving interface that ReqLLM.StreamServer
  expects when capturing streaming responses. Uses the Transcript format for
  storage.

  ## How it integrates with ReqLLM

  ReqLLM.StreamServer has built-in fixture capture support. When a stream completes,
  it checks for this module and calls `save_streaming_fixture/5`:

  From ReqLLM.StreamServer.finalize_stream_with_fixture/1 (line 533-566):

      if state.fixture_path && state.http_context && state.canonical_json && !state.fixture_saved? do
        case Code.ensure_loaded(ReqLLM.Step.Fixture.Backend) do
          {:module, ReqLLM.Step.Fixture.Backend} ->
            # Captures raw streaming chunks accumulated during the stream
            iodata = Enum.reverse(state.raw_iodata)

            apply(ReqLLM.Step.Fixture.Backend, :save_streaming_fixture, [
              state.http_context,
              state.fixture_path,
              state.canonical_json,
              state.model,
              iodata
            ])
        end
      end

  By implementing this module in our test support, we enable ReqLLM's native
  fixture capture without any modifications to ReqLLM itself!
  """

  require Logger
  alias ReqLLM.Test.Transcript

  @doc """
  Saves a streaming fixture to disk using Transcript format.

  Called by ReqLLM.StreamServer when a stream completes and fixture_path is set.

  ## Parameters
    * `http_context` - HTTPContext with request/response metadata
    * `fixture_path` - Path to save the fixture
    * `canonical_json` - The request body as JSON
    * `model` - ReqLLM.Model struct
    * `raw_iodata` - Raw streaming chunks as iodata (accumulated during stream)
  """
  def save_streaming_fixture(http_context, fixture_path, canonical_json, model, raw_iodata) do
    Logger.info("💾 Saving streaming fixture to #{Path.relative_to_cwd(fixture_path)}")

    # Ensure directory exists
    fixture_path |> Path.dirname() |> File.mkdir_p!()

    # Convert iodata to binary chunks
    chunks = iodata_to_chunks(raw_iodata)

    # Build events from chunks
    events =
      [
        {:status, http_context.status},
        {:headers, normalize_headers(http_context.resp_headers)}
      ] ++ Enum.map(chunks, &{:data, &1}) ++ [{:done, :ok}]

    # Create transcript
    transcript =
      Transcript.new(
        provider: model.provider,
        model_spec: model.model,
        captured_at: DateTime.utc_now(),
        request: %{
          method: http_context.method,
          url: http_context.url,
          headers: normalize_headers(http_context.req_headers),
          canonical_json: canonical_json
        },
        response_meta: %{
          status: http_context.status,
          headers: normalize_headers(http_context.resp_headers)
        },
        events: events
      )

    # Validate and write
    case Transcript.validate(transcript) do
      :ok ->
        Transcript.write!(transcript, fixture_path)
        Logger.info("✅ Saved fixture with #{length(chunks)} chunks")
        :ok

      {:error, reason} ->
        Logger.error("Failed to save fixture: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Convert iodata to list of binary chunks
  defp iodata_to_chunks(iodata) when is_list(iodata) do
    iodata
    |> Enum.map(&IO.iodata_to_binary/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp iodata_to_chunks(binary) when is_binary(binary) do
    [binary]
  end

  # Normalize headers to list of tuples
  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp normalize_headers(headers) when is_list(headers), do: headers
end
