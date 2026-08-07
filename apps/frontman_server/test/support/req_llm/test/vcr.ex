defmodule ReqLLM.Test.VCR do
  alias ReqLLM.Test.Transcript

  def load(path) do
    {:ok, Transcript.read!(path)}
  rescue
    e -> {:error, e}
  end

  def load!(path), do: Transcript.read!(path)

  def record(path, opts) do
    provider = Keyword.fetch!(opts, :provider)
    model = Keyword.fetch!(opts, :model)
    request = Keyword.fetch!(opts, :request)
    response = Keyword.fetch!(opts, :response)
    body = Keyword.fetch!(opts, :body)

    events = build_events_from_body(body, response)

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

  def replay_body(%Transcript{} = transcript) do
    Transcript.joined_data(transcript)
  end

  def replay_stream(%Transcript{} = transcript) do
    Stream.map(Transcript.data_chunks(transcript), & &1)
  end

  def status(%Transcript{events: events}) do
    case Enum.find(events, &match?({:status, _}, &1)) do
      {:status, code} -> code
      nil -> raise "No status event found in transcript"
    end
  end

  def headers(%Transcript{events: events}) do
    case Enum.find(events, &match?({:headers, _}, &1)) do
      {:headers, h} -> h
      nil -> []
    end
  end

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

  def streaming?(%Transcript{} = transcript) do
    Transcript.streaming?(transcript)
  end

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

    Task.async(fn ->
      Process.sleep(10)
      feed_transcript_to_server(server, transcript)
    end)

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
