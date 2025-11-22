defmodule ReqLLM.Test.VCR do
  @moduledoc """
  Record and replay HTTP transcripts for fixture-based testing.

  Test-only module that combines recording (from live API calls) and
  playback (from cached fixtures) in a unified interface. Uses the
  Transcript format for storage and ChunkCollector for streaming capture.

  ## Recording

      # Record from collected chunks (streaming)
      {:ok, collector} = ChunkCollector.start_link()
      # ... add chunks ...
      :ok = VCR.record(path, provider, model, request, response, collector)

      # Record from body (non-streaming)
      :ok = VCR.record(path, provider, model, request, response, body)

  ## Playback

      # Read transcript
      {:ok, transcript} = VCR.load(path)

      # Replay as single body
      body = VCR.replay_body(transcript)

      # Replay as stream
      stream = VCR.replay_stream(transcript)
  """

  alias ReqLLM.Test.{ChunkCollector, Transcript}

  @type provider :: atom()
  @type model_spec :: binary()
  @type request :: map()
  @type response :: map()

  @doc """
  Load a transcript from a fixture file.

  ## Examples

      {:ok, transcript} = VCR.load("test/fixtures/openai/basic.json")
      {:error, :enoent} = VCR.load("nonexistent.json")
  """
  @spec load(Path.t()) :: {:ok, Transcript.t()} | {:error, term()}
  def load(path) do
    {:ok, Transcript.read!(path)}
  rescue
    e -> {:error, e}
  end

  @doc """
  Load a transcript from a fixture file, raising on error.

  ## Examples

      transcript = VCR.load!("test/fixtures/openai/basic.json")
  """
  @spec load!(Path.t()) :: Transcript.t()
  def load!(path), do: Transcript.read!(path)

  @doc """
  Record a transcript from a ChunkCollector (streaming).

  ## Examples

      {:ok, collector} = ChunkCollector.start_link()
      ChunkCollector.add_chunk(collector, "data: chunk1\\n\\n")
      ChunkCollector.add_chunk(collector, "data: chunk2\\n\\n")

      :ok = VCR.record("fixtures/stream.json",
        provider: :openai,
        model: "gpt-4",
        request: %{method: "POST", url: "...", headers: [], canonical_json: %{}},
        response: %{status: 200, headers: []},
        collector: collector
      )
  """
  @spec record(Path.t(), keyword()) :: :ok | {:error, term()}
  def record(path, opts) do
    provider = Keyword.fetch!(opts, :provider)
    model = Keyword.fetch!(opts, :model)
    request = Keyword.fetch!(opts, :request)
    response = Keyword.fetch!(opts, :response)

    collector = Keyword.get(opts, :collector)
    body = Keyword.get(opts, :body)

    events =
      cond do
        collector != nil and body != nil ->
          raise ArgumentError, "cannot provide both :collector and :body"

        collector != nil ->
          build_events_from_collector(collector, response)

        body != nil ->
          build_events_from_body(body, response)

        true ->
          raise ArgumentError, "must provide either :collector or :body"
      end

    transcript =
      Transcript.new(
        provider: provider,
        model_spec: model,
        captured_at: DateTime.utc_now(),
        request: request,
        response_meta: response,
        events: events
      )

    case Transcript.validate(transcript) do
      :ok ->
        ensure_directory(path)
        Transcript.write!(transcript, path)
        :ok

      {:error, reason} ->
        {:error, {:validation_failed, reason}}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Replay a transcript as a single concatenated body.

  Joins all :data events into a single binary.

  ## Examples

      transcript = VCR.load!("fixtures/response.json")
      body = VCR.replay_body(transcript)
  """
  @spec replay_body(Transcript.t()) :: binary()
  def replay_body(%Transcript{} = transcript) do
    Transcript.joined_data(transcript)
  end

  @doc """
  Replay a transcript as a stream of data chunks.

  Returns an Enumerable that yields each :data event's binary content.

  ## Examples

      transcript = VCR.load!("fixtures/stream.json")
      stream = VCR.replay_stream(transcript)

      Enum.each(stream, fn chunk ->
        IO.puts("Received: \#{chunk}")
      end)
  """
  @spec replay_stream(Transcript.t()) :: Enumerable.t()
  def replay_stream(%Transcript{} = transcript) do
    Stream.map(Transcript.data_chunks(transcript), & &1)
  end

  @doc """
  Get the HTTP status code from a transcript.

  ## Examples

      status = VCR.status(transcript)  # => 200
  """
  @spec status(Transcript.t()) :: pos_integer()
  def status(%Transcript{events: events}) do
    case Enum.find(events, &match?({:status, _}, &1)) do
      {:status, code} -> code
      nil -> raise "No status event found in transcript"
    end
  end

  @doc """
  Get the HTTP headers from a transcript.

  ## Examples

      headers = VCR.headers(transcript)
  """
  @spec headers(Transcript.t()) :: [{binary(), binary()}]
  def headers(%Transcript{events: events}) do
    case Enum.find(events, &match?({:headers, _}, &1)) do
      {:headers, h} -> h
      nil -> []
    end
  end

  @doc """
  Replay streaming fixture into an existing StreamServer.

  Used by FinchClient to feed fixture data directly into StreamServer
  instead of making real HTTP calls. Feeds chunks asynchronously in a Task
  to mimic HTTP streaming behavior.

  ## Parameters

  - `path` - Absolute path to fixture Transcript JSON file
  - `stream_server_pid` - PID of the StreamServer to feed chunks into

  ## Returns

  `{:ok, task_pid}` - Task that feeds the chunks

  ## Examples

      {:ok, task_pid} =
        VCR.replay_into_stream_server(
          "test/support/fixtures/anthropic/text_generation/basic/model/stream.json",
          stream_server_pid
        )
  """
  @spec replay_into_stream_server(Path.t(), pid()) :: {:ok, pid()}
  def replay_into_stream_server(path, stream_server_pid) do
    transcript = load!(path)

    task =
      Task.async(fn ->
        Process.sleep(10)
        feed_transcript_to_server(stream_server_pid, transcript)
      end)

    {:ok, task.pid}
  end

  defp feed_transcript_to_server(server, %Transcript{events: events}) do
    Enum.each(events, fn event ->
      case event do
        {:status, code} ->
          GenServer.call(server, {:http_event, {:status, code}})

        {:headers, headers} ->
          GenServer.call(server, {:http_event, {:headers, headers}})

        {:data, binary} ->
          GenServer.call(server, {:http_event, {:data, binary}})

        {:done, :ok} ->
          GenServer.call(server, {:http_event, :done})

        _ ->
          :ok
      end
    end)
  end

  defp build_events_from_collector(collector, response) do
    chunks = ChunkCollector.finish(collector)
    status_event = {:status, Map.get(response, :status, 200)}
    headers_event = {:headers, Map.get(response, :headers, [])}

    # Filter out empty chunks (trailing reads or boundaries)
    data_events =
      chunks
      |> Enum.map(fn %{bin: bin} -> bin end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&{:data, &1})

    done_event = {:done, :ok}

    [status_event, headers_event] ++ data_events ++ [done_event]
  end

  defp build_events_from_body(body, response) do
    headers =
      case Map.get(response, :headers, []) do
        h when is_list(h) -> h
        h when is_map(h) -> Enum.to_list(h)
        _ -> []
      end

    [
      {:status, Map.get(response, :status, 200)},
      {:headers, headers},
      {:data, body},
      {:done, :ok}
    ]
  end

  @doc """
  Check if a transcript represents streaming data.

  ## Examples

      {:ok, transcript} = VCR.load("fixtures/stream.json")
      VCR.streaming?(transcript)  # => true
  """
  @spec streaming?(Transcript.t()) :: boolean()
  def streaming?(%Transcript{} = transcript) do
    Transcript.streaming?(transcript)
  end

  @doc """
  Replay a transcript as a raw response body (JSON decoded).

  For non-streaming fixtures, decodes the single data event as JSON.
  Useful for Step API compatibility.

  ## Examples

      {:ok, transcript} = VCR.load("fixtures/response.json")
      body = VCR.replay_response_body(transcript)
      # => %{"content" => [...], "model" => "..."}
  """
  @spec replay_response_body(Transcript.t()) :: map()
  def replay_response_body(%Transcript{} = transcript) do
    if Transcript.streaming?(transcript) do
      raise ArgumentError, """
      Cannot replay streaming transcript as response body.
      Use replay_stream/1 instead.
      """
    end

    transcript
    |> Transcript.joined_data()
    |> Jason.decode!()
  end

  @doc """
  Replay a transcript as a stream for Step API.

  Returns a Stream that yields decoded provider response chunks.
  Used by the legacy Step API for compatibility.

  ## Examples

      {:ok, transcript} = VCR.load("fixtures/stream.json")
      stream = VCR.replay_as_stream(transcript, provider_mod, model)
  """
  @spec replay_as_stream(Transcript.t(), module(), LLMDB.Model.t()) :: Enumerable.t()
  def replay_as_stream(%Transcript{} = transcript, provider_mod, model) do
    alias ReqLLM.StreamServer

    if !Transcript.streaming?(transcript) do
      raise ArgumentError, """
      Cannot replay non-streaming transcript as stream.
      Use replay_response_body/1 instead.
      """
    end

    {:ok, server} =
      StreamServer.start_link(
        provider_mod: provider_mod,
        model: model
      )

    # Feed transcript events to server
    Task.async(fn ->
      Process.sleep(10)
      feed_transcript_to_server(server, transcript)
    end)

    # Return stream from server
    Stream.resource(
      fn -> server end,
      fn server ->
        case StreamServer.next(server, 5_000) do
          {:ok, chunk} -> {[chunk], server}
          :halt -> {:halt, server}
          {:error, reason} -> raise "Stream error: #{inspect(reason)}"
        end
      end,
      fn server ->
        if Process.alive?(server) do
          GenServer.stop(server, :normal)
        end
      end
    )
  end

  defp ensure_directory(path) do
    path |> Path.dirname() |> File.mkdir_p!()
  end
end
