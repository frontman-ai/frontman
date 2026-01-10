defmodule ReqLLM.Test.Transcript do
  @moduledoc """
  Universal HTTP transcript format for fixture recording and replay.

  Test-only module for capturing and replaying HTTP interactions.
  Represents a complete HTTP request/response cycle as a series of events.
  Both streaming and non-streaming responses use the same event structure.

  ## Event Types

  - `{:status, code}` - HTTP status code received
  - `{:headers, headers}` - HTTP headers received
  - `{:data, binary}` - Response body chunk
  - `{:done, :ok}` - Response complete
  """

  use TypedStruct

  @typedoc "HTTP event in the transcript"
  @type event ::
          {:status, pos_integer()}
          | {:headers, [{binary(), binary()}]}
          | {:data, binary()}
          | {:done, :ok}

  typedstruct do
    field(:provider, atom(), enforce: true)
    field(:model_spec, binary(), enforce: true)
    field(:captured_at, DateTime.t(), enforce: true)
    field(:request, map(), enforce: true)
    field(:response_meta, map(), enforce: true)
    field(:events, [event()], enforce: true)
  end

  @sensitive_headers ~w(authorization x-api-key api-key)
  # Use exact matches to avoid false positives (e.g., max_tokens matching "token")
  @sensitive_json_keys ~w(api_key apiKey authorization access_token auth_token bearer_token)

  @spec new(keyword()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)

  @spec validate(t()) :: :ok | {:error, binary()}
  def validate(%__MODULE__{} = t) do
    with :ok <- validate_provider(t.provider),
         :ok <- validate_model_spec(t.model_spec),
         :ok <- validate_request(t.request),
         :ok <- validate_response_meta(t.response_meta),
         do: validate_events(t.events)
  end

  @spec streaming?(t()) :: boolean()
  def streaming?(%__MODULE__{events: events}) do
    Enum.count(events, &match?({:data, _}, &1)) > 1
  end

  @spec data_chunks(t()) :: [binary()]
  def data_chunks(%__MODULE__{events: events}) do
    for {:data, chunk} <- events, do: chunk
  end

  @spec joined_data(t()) :: binary()
  def joined_data(%__MODULE__{} = t) do
    t |> data_chunks() |> IO.iodata_to_binary()
  end

  @doc "Encode transcript to pretty JSON"
  @spec to_json(t()) :: binary()
  def to_json(%__MODULE__{} = t) do
    t |> to_map() |> Jason.encode!(pretty: true)
  end

  @doc "Decode transcript from JSON"
  @spec from_json!(binary()) :: t()
  def from_json!(json) do
    json |> Jason.decode!() |> from_map()
  end

  @doc "Write transcript to file as JSON"
  @spec write!(t(), Path.t()) :: :ok
  def write!(%__MODULE__{} = t, path) do
    json = to_json(t)
    File.write!(path, json)
  end

  @doc "Read transcript from JSON file"
  @spec read!(Path.t()) :: t()
  def read!(path) do
    if !File.exists?(path) do
      raise ArgumentError, """
      Fixture file not found: #{path}

      To generate this fixture, run:
        REQ_LLM_FIXTURES_MODE=record mix test --only "provider:#{extract_provider_from_path(path)}"
      """
    end

    content = File.read!(path)

    if content == "" do
      raise ArgumentError, """
      Fixture file is empty: #{path}

      This file exists but contains no data. To regenerate this fixture, run:
        REQ_LLM_FIXTURES_MODE=record mix test --only "provider:#{extract_provider_from_path(path)}"
      """
    end

    from_json!(content)
  end

  defp extract_provider_from_path(path) do
    path |> Path.split() |> Enum.find(&(&1 in ~w[openai anthropic google groq xai openrouter]))
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = t) do
    if streaming?(t) do
      to_streaming_format(t)
    else
      to_non_streaming_format(t)
    end
  end

  defp to_streaming_format(t) do
    %{
      "provider" => Atom.to_string(t.provider),
      "model_spec" => t.model_spec,
      "request" => build_request_map(t),
      "response" => build_streaming_response_map(t),
      "captured_at" => DateTime.to_iso8601(t.captured_at),
      "chunks" => build_chunks_array(t)
    }
  end

  defp to_non_streaming_format(t) do
    %{
      "provider" => Atom.to_string(t.provider),
      "model_spec" => t.model_spec,
      "request" => build_request_map(t),
      "response" => build_non_streaming_response_map(t)
    }
  end

  defp build_request_map(t) do
    req = sanitize_request(t.request)

    canonical_json_obj =
      case req["canonical_json"] do
        s when is_binary(s) ->
          case Jason.decode(s) do
            {:ok, obj} -> obj
            {:error, _} -> %{}
          end

        m when is_map(m) ->
          m

        _ ->
          %{}
      end

    canonical_json_str =
      case req["canonical_json"] do
        s when is_binary(s) -> s
        m when is_map(m) -> Jason.encode!(m)
        _ -> "{}"
      end

    %{
      "method" => req["method"],
      "url" => req["url"],
      "headers" => req["headers"],
      "canonical_json" => canonical_json_obj,
      "body" => %{"b64" => Base.encode64(canonical_json_str)}
    }
  end

  defp build_streaming_response_map(t) do
    %{
      "status" => t.response_meta[:status] || t.response_meta["status"],
      "headers" => headers_to_map(t.response_meta[:headers] || t.response_meta["headers"] || []),
      "body" => nil
    }
  end

  defp build_non_streaming_response_map(t) do
    body_data = joined_data(t)

    parsed_body =
      case Jason.decode(body_data) do
        {:ok, decoded} -> decoded
        {:error, _} -> %{"b64" => Base.encode64(body_data)}
      end

    %{
      "status" => t.response_meta[:status] || t.response_meta["status"],
      "headers" => headers_to_map(t.response_meta[:headers] || t.response_meta["headers"] || []),
      "body" => parsed_body
    }
  end

  defp build_chunks_array(t) do
    data_chunks(t)
    |> Enum.map(fn chunk ->
      %{
        "b64" => Base.encode64(chunk)
      }
    end)
  end

  @spec from_map(map()) :: t()
  def from_map(m) do
    cond do
      has_chunks?(m) ->
        from_streaming_format(m)

      has_events?(m) ->
        from_event_format(m)

      true ->
        from_non_streaming_format(m)
    end
  end

  defp has_chunks?(m), do: Map.has_key?(m, "chunks")
  defp has_events?(m), do: Map.has_key?(m, "events")

  defp from_event_format(m) do
    new(
      provider: String.to_atom(m["provider"]),
      model_spec: m["model_spec"],
      captured_at: parse_datetime(m["captured_at"]),
      request: m["request"],
      response_meta: m["response"],
      events: Enum.map(m["events"], &decode_event/1)
    )
  end

  defp from_streaming_format(m) do
    request = m["request"]
    response = m["response"]
    chunks = m["chunks"] || []

    events = build_events_from_chunks(chunks, response)

    provider = derive_provider_from_request(request)
    model_spec = derive_model_spec_from_request(request)

    new(
      provider: provider,
      model_spec: model_spec,
      captured_at: parse_datetime(m["captured_at"]),
      request: normalize_request(request),
      response_meta: normalize_response(response),
      events: events
    )
  end

  defp from_non_streaming_format(m) do
    request = m["request"]
    response = m["response"]

    events = build_events_from_response_body(response)

    provider = derive_provider_from_request(request)
    model_spec = derive_model_spec_from_request(request)

    new(
      provider: provider,
      model_spec: model_spec,
      captured_at: DateTime.utc_now(),
      request: normalize_request(request),
      response_meta: normalize_response(response),
      events: events
    )
  end

  defp build_events_from_chunks(chunks, response) do
    status_event = {:status, response["status"] || 200}
    headers_event = {:headers, normalize_headers(response["headers"] || %{})}

    data_events =
      Enum.map(chunks, fn chunk ->
        binary =
          cond do
            # New format: {"b64": "base64data"}
            is_map(chunk) && Map.has_key?(chunk, "b64") ->
              Base.decode64!(chunk["b64"])

            # Legacy format: plain string
            is_binary(chunk) ->
              chunk

            true ->
              raise "Unknown chunk format: #{inspect(chunk)}"
          end

        {:data, binary}
      end)

    [status_event, headers_event] ++ data_events ++ [{:done, :ok}]
  end

  defp build_events_from_response_body(response) do
    status = response["status"] || 200
    headers = response["headers"] || %{}
    body = response["body"]

    body_binary =
      cond do
        is_map(body) && Map.has_key?(body, "b64") ->
          Base.decode64!(body["b64"])

        is_map(body) ->
          Jason.encode!(body, pretty: false)

        is_binary(body) ->
          body

        true ->
          ""
      end

    [
      {:status, status},
      {:headers, normalize_headers(headers)},
      {:data, body_binary},
      {:done, :ok}
    ]
  end

  defp derive_provider_from_request(request) do
    url = request["url"] || ""

    cond do
      String.contains?(url, "anthropic.com") -> :anthropic
      String.contains?(url, "openai.com") -> :openai
      String.contains?(url, "googleapis.com") -> :google
      String.contains?(url, "groq.com") -> :groq
      String.contains?(url, "openrouter.ai") -> :openrouter
      String.contains?(url, "x.ai") -> :xai
      true -> :unknown
    end
  end

  defp derive_model_spec_from_request(request) do
    canonical_json = request["canonical_json"]

    model_name =
      cond do
        is_binary(canonical_json) ->
          case Jason.decode(canonical_json) do
            {:ok, json} -> Map.get(json, "model")
            _ -> nil
          end

        is_map(canonical_json) ->
          Map.get(canonical_json, "model")

        true ->
          nil
      end

    if model_name do
      if String.contains?(model_name, ":") do
        model_name
      else
        provider = derive_provider_from_request(request)
        "#{provider}:#{model_name}"
      end
    else
      "unknown:unknown"
    end
  end

  defp normalize_request(req) do
    %{
      method: req["method"],
      url: req["url"],
      headers: req["headers"] || %{},
      canonical_json: req["canonical_json"] || req["body"]
    }
  end

  defp normalize_response(resp) do
    %{
      status: resp["status"] || 200,
      headers: resp["headers"] || %{}
    }
  end

  defp decode_event(%{"type" => "status", "value" => c}), do: {:status, c}

  defp decode_event(%{"type" => "headers", "value" => h}), do: {:headers, normalize_headers(h)}

  defp decode_event(%{"type" => "data", "b64" => b64}), do: {:data, Base.decode64!(b64)}
  defp decode_event(%{"type" => "done"}), do: {:done, :ok}

  defp sanitize_request(req) do
    req
    |> Map.new(fn
      {:headers, v} -> {"headers", sanitize_headers(v) |> headers_to_map()}
      {"headers", v} -> {"headers", sanitize_headers(v) |> headers_to_map()}
      {:canonical_json, v} -> {"canonical_json", sanitize_json(v)}
      {"canonical_json", v} -> {"canonical_json", sanitize_json(v)}
      {:url, v} -> {"url", sanitize_url(v)}
      {"url", v} -> {"url", sanitize_url(v)}
      {k, v} when is_atom(k) -> {to_string(k), v}
      other -> other
    end)
  end

  defp headers_to_map(headers) when is_list(headers), do: Map.new(headers)
  defp headers_to_map(headers) when is_map(headers), do: headers

  defp sanitize_headers(headers) when is_list(headers) do
    for {k, v} <- headers do
      {k,
       if(String.downcase(to_string(k)) in @sensitive_headers,
         do: "[REDACTED:#{k}]",
         else: v
       )}
    end
  end

  defp sanitize_headers(headers) when is_map(headers) do
    headers |> Enum.to_list() |> sanitize_headers() |> Map.new()
  end

  defp sanitize_json(m) when is_map(m) do
    for {k, v} <- m, into: %{} do
      k_str = to_string(k) |> String.downcase()

      {k,
       if(k_str in @sensitive_json_keys,
         do: "[REDACTED:#{k}]",
         else: sanitize_json(v)
       )}
    end
  end

  defp sanitize_json(list) when is_list(list), do: Enum.map(list, &sanitize_json/1)
  defp sanitize_json(other), do: other

  @sensitive_query_keys ["key", "api_key", "apikey", "access_token", "token"]

  defp sanitize_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.query do
      sanitized_query =
        uri.query
        |> URI.decode_query()
        |> Enum.map(&sanitize_query_param/1)
        |> URI.encode_query()

      %{uri | query: sanitized_query} |> URI.to_string()
    else
      url
    end
  end

  defp sanitize_url(url), do: url

  defp sanitize_query_param({k, v}) do
    if String.downcase(k) in @sensitive_query_keys,
      do: {k, "[REDACTED:#{k}]"},
      else: {k, v}
  end

  defp normalize_headers(h) when is_list(h), do: h
  defp normalize_headers(h) when is_map(h), do: Enum.to_list(h)

  defp parse_datetime(iso) do
    {:ok, dt, 0} = DateTime.from_iso8601(iso)
    dt
  end

  defp validate_provider(p) when is_atom(p), do: :ok
  defp validate_provider(_), do: {:error, "provider must be an atom"}

  defp validate_model_spec(s) when is_binary(s) and byte_size(s) > 0, do: :ok
  defp validate_model_spec(_), do: {:error, "model_spec must be a non-empty string"}

  defp validate_request(%{} = r) do
    required = [:method, :url, :headers, :canonical_json]

    case required -- Map.keys(r) do
      [] -> :ok
      missing -> {:error, "request missing: #{inspect(missing)}"}
    end
  end

  defp validate_request(_), do: {:error, "request must be a map"}

  defp validate_response_meta(%{} = r) do
    required = [:status, :headers]

    case required -- Map.keys(r) do
      [] -> :ok
      missing -> {:error, "response_meta missing: #{inspect(missing)}"}
    end
  end

  defp validate_response_meta(_), do: {:error, "response_meta must be a map"}

  defp validate_events(events) when is_list(events) do
    if Enum.all?(events, &valid_event?/1), do: :ok, else: {:error, "invalid event types"}
  end

  defp validate_events(_), do: {:error, "events must be a list"}

  defp valid_event?({:status, c}) when is_integer(c) and c > 0, do: true
  defp valid_event?({:headers, h}) when is_list(h), do: true
  defp valid_event?({:data, d}) when is_binary(d), do: true
  defp valid_event?({:done, :ok}), do: true
  defp valid_event?(_), do: false
end
