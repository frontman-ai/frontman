# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule ModelContextProtocol do
  @moduledoc """
  MCP (Model Context Protocol) message builders and parsers.

  Provides MCP-specific request building and response parsing, composing
  the JsonRpc module for wire format. Similar to how the ACP module handles
  Agent Client Protocol messages.

  This module:
  - Builds MCP requests
  - Extracts data from MCP-specific response formats
  - Handles MCP content arrays and error flags

  Use with JsonRpc for complete message handling.
  """

  use Boundary, deps: [JsonRpc], exports: :all

  alias ModelContextProtocol.ToolCallParams

  @protocol_version "2026-07-28"
  @client_name "frontman-server"
  @client_version "1.0.0"
  @execution_context "ai.frontman/execution-context"
  @safe_integer_max 9_007_199_254_740_991
  @metadata_bytes_max 16_384
  @metadata_keys_max 64
  @reserved_metadata_keys ["baggage", "traceparent", "tracestate"]
  @metadata_key_regex ~r/^(?:[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\/)?(?:[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)?$/

  @error_header_mismatch -32_020
  @error_missing_required_client_capability -32_021
  @error_unsupported_protocol_version -32_022

  @spec protocol_version() :: String.t()
  def protocol_version, do: @protocol_version

  @spec client_info() :: map()
  def client_info do
    %{
      "name" => @client_name,
      "version" => @client_version
    }
  end

  @spec client_capabilities() :: map()
  def client_capabilities do
    %{"extensions" => %{@execution_context => %{"version" => 1}}}
  end

  @spec request_meta() :: map()
  def request_meta do
    %{
      "io.modelcontextprotocol/protocolVersion" => @protocol_version,
      "io.modelcontextprotocol/clientCapabilities" => client_capabilities(),
      "io.modelcontextprotocol/clientInfo" => client_info()
    }
  end

  @spec tool_result_text(String.t()) :: map()
  def tool_result_text(text) when is_binary(text) do
    complete_result([%{"type" => "text", "text" => text}], false)
  end

  @spec tool_result_json(term()) :: map()
  def tool_result_json(value) do
    value
    |> Jason.encode!()
    |> then(
      &Map.put(
        complete_result([%{"type" => "text", "text" => &1}], false),
        "structuredContent",
        value
      )
    )
  end

  @spec tool_result_image(String.t(), String.t()) :: map()
  def tool_result_image(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    complete_result([%{"type" => "image", "data" => data, "mimeType" => mime_type}], false)
  end

  @spec tool_result_error(String.t()) :: map()
  def tool_result_error(text) when is_binary(text) do
    complete_result([%{"type" => "text", "text" => text}], true)
  end

  @spec validate_tool_result(term()) :: :ok | {:error, :invalid_call_tool_result}
  def validate_tool_result(%{"resultType" => "complete", "content" => content} = result)
      when is_list(content) do
    validate_call_result_fields(result)
  end

  def validate_tool_result(_result), do: {:error, :invalid_call_tool_result}

  @spec discover_request(String.t() | integer()) :: map()
  def discover_request(request_id) do
    request(request_id, "server/discover", %{"_meta" => request_meta()})
  end

  @spec list_tools_request(String.t() | integer()) :: map()
  def list_tools_request(request_id) do
    request(request_id, "tools/list", %{"_meta" => request_meta()})
  end

  @spec cancelled_notification(String.t() | integer(), String.t() | nil) :: map()
  def cancelled_notification(request_id, reason \\ nil) do
    params = %{"requestId" => validate_id!(request_id)}
    params = if is_binary(reason), do: Map.put(params, "reason", reason), else: params
    JsonRpc.notification("notifications/cancelled", params)
  end

  @doc """
  Extracts text content from MCP content array.

  MCP responses contain a content array with text blocks:
  %{"content" => [%{"type" => "text", "text" => "..."}]}
  """
  @spec extract_content_text(map()) :: String.t()
  def extract_content_text(%{"content" => content}) when is_list(content) do
    Enum.map_join(content, "\n", fn
      %{"text" => text} -> text
      _ -> ""
    end)
  end

  def extract_content_text(_), do: ""

  @doc """
  Checks if MCP result indicates an error.
  """
  @spec error?(map()) :: boolean()
  def error?(%{"isError" => is_error}) when is_boolean(is_error), do: is_error
  def error?(_), do: false

  @doc """
  Builds an MCP tool execution request.

  Uses a JSON-RPC request id for protocol correlation and carries durable
  execution identity in MCP request metadata.
  """
  @spec build_tool_execution(ToolCallParams.t()) :: map()
  def build_tool_execution(%ToolCallParams{tool_name: tool_name, arguments: arguments} = params)
      when is_binary(tool_name) and is_map(arguments) do
    request(params.request_id, "tools/call", %{
      "name" => params.tool_name,
      "arguments" => params.arguments,
      "_meta" => execution_context_meta(params.task_id, params.tool_call_id)
    })
  end

  @spec parse_response(map(), String.t()) ::
          {:ok, {:success, String.t() | integer(), map()}}
          | {:ok, {:error, String.t() | integer() | nil, map()}}
          | {:error, atom()}
  def parse_response(message, method) when is_map(message) and is_binary(method) do
    with :ok <- validate_response_envelope(message),
         {:ok, parsed} <- parse_response_body(message),
         normalized <- normalize_method_result(parsed),
         :ok <- validate_method_response(normalized, method) do
      {:ok, normalized}
    end
  end

  def parse_response(_message, _method), do: {:error, :invalid_message}

  @spec parse_response(map()) ::
          {:ok, {:success, String.t() | integer(), map()}}
          | {:ok, {:error, String.t() | integer() | nil, map()}}
          | {:error, atom()}
  def parse_response(message) when is_map(message) do
    with :ok <- validate_response_envelope(message) do
      parse_response_body(message)
    end
  end

  def parse_response(_message), do: {:error, :invalid_message}

  @spec header_mismatch_error?(map()) :: boolean()
  def header_mismatch_error?(error) do
    named_error?(error, @error_header_mismatch) and valid_named_error?(error)
  end

  @spec missing_required_client_capability_error?(map()) :: boolean()
  def missing_required_client_capability_error?(error) do
    named_error?(error, @error_missing_required_client_capability) and valid_named_error?(error)
  end

  @spec unsupported_protocol_version_error?(map()) :: boolean()
  def unsupported_protocol_version_error?(error) do
    named_error?(error, @error_unsupported_protocol_version) and valid_named_error?(error)
  end

  @spec validate_discovery_compatibility(map()) :: :ok | {:error, String.t()}
  def validate_discovery_compatibility(result) when is_map(result) do
    with true <- @protocol_version in Map.fetch!(result, "supportedVersions"),
         %{"version" => 1} <- get_in(result, ["capabilities", "extensions", @execution_context]) do
      :ok
    else
      false -> {:error, "unsupported_protocol_version"}
      _missing_or_incompatible -> {:error, "missing_required_server_extension"}
    end
  end

  defp execution_context_meta(task_id, tool_call_id)
       when is_binary(task_id) and byte_size(task_id) > 0 and is_binary(tool_call_id) and
              byte_size(tool_call_id) > 0 do
    Map.put(request_meta(), @execution_context, %{
      "taskId" => task_id,
      "toolCallId" => tool_call_id
    })
  end

  defp request(id, method, params), do: JsonRpc.request(validate_id!(id), method, params)

  defp validate_id!(id) when is_binary(id), do: id
  defp validate_id!(id) when is_integer(id) and abs(id) <= @safe_integer_max, do: id
  defp validate_id!(id), do: raise(ArgumentError, "invalid MCP request id: #{inspect(id)}")

  defp validate_response_envelope(%{"jsonrpc" => "2.0"} = message) do
    case validate_response_exclusivity(message) do
      :ok -> validate_optional_id(message)
      error -> error
    end
  end

  defp validate_response_envelope(%{"jsonrpc" => _}), do: {:error, :invalid_version}
  defp validate_response_envelope(_message), do: {:error, :invalid_message}

  defp validate_response_exclusivity(message) do
    case Enum.count(["method", "result", "error"], &Map.has_key?(message, &1)) do
      1 -> :ok
      _ -> {:error, :invalid_message}
    end
  end

  defp validate_optional_id(%{"error" => _error, "id" => nil}), do: :ok

  defp validate_optional_id(%{"id" => id}) do
    case valid_id?(id) do
      true -> :ok
      false -> {:error, :invalid_id}
    end
  end

  defp validate_optional_id(_message), do: :ok
  defp valid_id?(id) when is_binary(id), do: true
  defp valid_id?(id) when is_integer(id), do: abs(id) <= @safe_integer_max
  defp valid_id?(_id), do: false

  defp parse_response_body(%{"id" => id, "result" => result}) when is_map(result),
    do: {:ok, {:success, id, result}}

  defp parse_response_body(%{"error" => %{"code" => code, "message" => message} = error} = body)
       when is_integer(code) and is_binary(message) do
    case valid_named_error?(error) do
      true -> {:ok, {:error, Map.get(body, "id"), error}}
      false -> {:error, :invalid_error}
    end
  end

  defp parse_response_body(_message), do: {:error, :invalid_message}

  defp normalize_method_result({:success, id, result}) do
    {:success, id, Map.put_new(result, "resultType", "complete")}
  end

  defp normalize_method_result({:error, _id, _error} = parsed), do: parsed

  defp validate_method_response({:error, _id, _error}, _method), do: :ok

  defp validate_method_response({:success, _id, result}, "server/discover"),
    do: validate_discover_result(result)

  defp validate_method_response({:success, _id, result}, "tools/list"),
    do: validate_tools_list_result(result)

  defp validate_method_response({:success, _id, result}, "tools/call"),
    do: validate_call_tool_response(result)

  defp validate_method_response(_parsed, _method), do: {:error, :unknown_method}

  defp validate_discover_result(result) do
    case result do
      %{
        "resultType" => "complete",
        "supportedVersions" => versions,
        "capabilities" => capabilities,
        "ttlMs" => ttl,
        "cacheScope" => scope
      }
      when is_list(versions) and is_map(capabilities) and is_integer(ttl) and
             ttl >= 0 and scope in ["private", "public"] ->
        with :ok <- validate_versions(versions),
             :ok <- validate_server_capabilities(capabilities),
             :ok <- validate_optional_string(result, "instructions"),
             :ok <- validate_optional_result_meta(result) do
          :ok
        else
          _ -> {:error, :invalid_discover_result}
        end

      _ ->
        {:error, :invalid_discover_result}
    end
  end

  defp validate_tools_list_result(result) do
    case result do
      %{"resultType" => "complete", "tools" => tools, "ttlMs" => ttl, "cacheScope" => scope}
      when is_list(tools) and is_integer(ttl) and ttl >= 0 and
             scope in ["private", "public"] ->
        with :ok <- validate_tools(tools),
             :ok <- validate_optional_string(result, "nextCursor"),
             :ok <- validate_optional_result_meta(result) do
          :ok
        else
          _ -> {:error, :invalid_tools_list_result}
        end

      _ ->
        {:error, :invalid_tools_list_result}
    end
  end

  defp validate_call_tool_response(%{"resultType" => "complete"} = result),
    do: validate_tool_result(result)

  defp validate_call_tool_response(%{"resultType" => "input_required"} = result),
    do: validate_input_required_result(result)

  defp validate_call_tool_response(_result), do: {:error, :invalid_call_tool_result}

  defp validate_versions(versions) do
    case Enum.all?(versions, &is_binary/1) do
      true -> :ok
      false -> {:error, :invalid_discover_result}
    end
  end

  defp validate_server_capabilities(capabilities) do
    with true <- optional_map?(capabilities, "completions"),
         true <- optional_map?(capabilities, "experimental"),
         true <- optional_map?(capabilities, "extensions"),
         true <- optional_map?(capabilities, "logging"),
         true <- optional_map?(capabilities, "prompts"),
         true <- optional_map?(capabilities, "resources"),
         true <- optional_map?(capabilities, "tools") do
      validate_capability_fields(capabilities)
    else
      false -> {:error, :invalid_server_capabilities}
    end
  end

  defp validate_capability_fields(capabilities) do
    with true <- valid_extension_map?(Map.get(capabilities, "extensions")),
         true <- valid_experimental_map?(Map.get(capabilities, "experimental")),
         true <- valid_list_changed?(Map.get(capabilities, "prompts")),
         true <- valid_resources_capability?(Map.get(capabilities, "resources")),
         true <- valid_list_changed?(Map.get(capabilities, "tools")) do
      :ok
    else
      false -> {:error, :invalid_server_capabilities}
    end
  end

  defp valid_extension_map?(nil), do: true

  defp valid_extension_map?(extensions),
    do: Enum.all?(extensions, fn {_key, value} -> is_map(value) end)

  defp valid_experimental_map?(nil), do: true

  defp valid_experimental_map?(experimental) do
    Enum.all?(experimental, fn {_key, value} -> is_map(value) end)
  end

  defp valid_list_changed?(nil), do: true
  defp valid_list_changed?(capability), do: optional_boolean?(capability, "listChanged")

  defp valid_resources_capability?(nil), do: true

  defp valid_resources_capability?(capability) do
    optional_boolean?(capability, "listChanged") and optional_boolean?(capability, "subscribe")
  end

  defp validate_tools(tools) do
    case Enum.all?(tools, &valid_tool?/1) do
      true -> :ok
      false -> {:error, :invalid_tools_list_result}
    end
  end

  defp valid_tool?(%{"name" => name, "inputSchema" => %{"type" => "object"}} = tool)
       when is_binary(name) do
    optional_binary?(tool, "title") and optional_binary?(tool, "description") and
      valid_tool_schema?(tool["inputSchema"]) and
      valid_optional_tool_schema?(tool, "outputSchema") and
      valid_optional_icons?(tool, "icons") and valid_tool_annotations?(tool["annotations"]) and
      optional_metadata?(tool, "_meta")
  end

  defp valid_tool?(_tool), do: false

  defp valid_tool_schema?(schema), do: optional_binary?(schema, "$schema")

  defp valid_optional_tool_schema?(tool, key) do
    case Map.fetch(tool, key) do
      :error -> true
      {:ok, schema} when is_map(schema) -> valid_tool_schema?(schema)
      {:ok, _schema} -> false
    end
  end

  defp valid_tool_annotations?(nil), do: true

  defp valid_tool_annotations?(annotations) when is_map(annotations) do
    optional_boolean?(annotations, "destructiveHint") and
      optional_boolean?(annotations, "idempotentHint") and
      optional_boolean?(annotations, "openWorldHint") and
      optional_boolean?(annotations, "readOnlyHint") and optional_binary?(annotations, "title")
  end

  defp valid_tool_annotations?(_annotations), do: false

  defp validate_call_result_fields(result) do
    with true <- Enum.all?(result["content"], &valid_content_block?/1),
         true <- optional_boolean?(result, "isError"),
         :ok <- validate_optional_result_meta(result) do
      :ok
    else
      _invalid -> {:error, :invalid_call_tool_result}
    end
  end

  defp validate_input_required_result(result) do
    with true <- valid_input_required_fields?(result),
         :ok <- validate_optional_result_meta(result) do
      :ok
    else
      _invalid -> {:error, :invalid_call_tool_result}
    end
  end

  defp valid_input_required_fields?(%{"inputRequests" => requests} = result)
       when is_map(requests) do
    Enum.all?(requests, fn {_id, request} -> valid_input_request?(request) end) and
      optional_binary?(result, "requestState")
  end

  defp valid_input_required_fields?(%{"requestState" => request_state} = result)
       when is_binary(request_state) do
    optional_input_requests?(result)
  end

  defp valid_input_required_fields?(_result), do: false

  defp optional_input_requests?(result) do
    case Map.fetch(result, "inputRequests") do
      :error ->
        true

      {:ok, requests} when is_map(requests) ->
        Enum.all?(requests, fn {_id, request} -> valid_input_request?(request) end)

      {:ok, _requests} ->
        false
    end
  end

  defp valid_input_request?(%{"method" => "roots/list"} = request) do
    case Map.fetch(request, "params") do
      :error -> true
      {:ok, params} when is_map(params) -> optional_metadata?(params, "_meta")
      {:ok, _params} -> false
    end
  end

  defp valid_input_request?(%{"method" => "elicitation/create", "params" => params})
       when is_map(params),
       do: valid_elicitation_params?(params)

  defp valid_input_request?(%{"method" => "sampling/createMessage", "params" => params})
       when is_map(params),
       do: valid_sampling_params?(params)

  defp valid_input_request?(_request), do: false

  defp valid_elicitation_params?(%{"mode" => "url", "message" => message, "url" => url})
       when is_binary(message),
       do: valid_uri?(url)

  defp valid_elicitation_params?(
         %{
           "message" => message,
           "requestedSchema" => %{"type" => "object", "properties" => properties} = schema
         } = params
       )
       when is_binary(message) and is_map(properties) do
    optional_form_mode?(params) and optional_binary?(schema, "$schema") and
      optional_string_list?(schema, "required") and
      Enum.all?(properties, fn {_name, definition} -> valid_primitive_schema?(definition) end)
  end

  defp valid_elicitation_params?(_params), do: false

  defp optional_form_mode?(params) do
    case Map.fetch(params, "mode") do
      :error -> true
      {:ok, "form"} -> true
      {:ok, _mode} -> false
    end
  end

  defp valid_primitive_schema?(%{"type" => "string"} = schema) do
    optional_binary?(schema, "title") and optional_binary?(schema, "description") and
      optional_non_negative_integer?(schema, "minLength") and
      optional_non_negative_integer?(schema, "maxLength") and optional_format?(schema) and
      optional_binary?(schema, "default") and valid_string_choices?(schema)
  end

  defp valid_primitive_schema?(%{"type" => type} = schema) when type in ["integer", "number"] do
    optional_binary?(schema, "title") and optional_binary?(schema, "description") and
      optional_number?(schema, "minimum") and optional_number?(schema, "maximum") and
      optional_number?(schema, "default")
  end

  defp valid_primitive_schema?(%{"type" => "boolean"} = schema) do
    optional_binary?(schema, "title") and optional_binary?(schema, "description") and
      optional_boolean?(schema, "default")
  end

  defp valid_primitive_schema?(%{"type" => "array", "items" => items} = schema)
       when is_map(items) do
    optional_binary?(schema, "title") and optional_binary?(schema, "description") and
      optional_non_negative_integer?(schema, "minItems") and
      optional_non_negative_integer?(schema, "maxItems") and
      optional_string_list?(schema, "default") and valid_array_choices?(items)
  end

  defp valid_primitive_schema?(_schema), do: false

  defp valid_string_choices?(%{"oneOf" => choices}) when is_list(choices),
    do: Enum.all?(choices, &valid_titled_choice?/1)

  defp valid_string_choices?(%{"enum" => choices} = schema) when is_list(choices) do
    Enum.all?(choices, &is_binary/1) and optional_string_list?(schema, "enumNames")
  end

  defp valid_string_choices?(_schema), do: true

  defp valid_array_choices?(%{"type" => "string", "enum" => choices}) when is_list(choices),
    do: Enum.all?(choices, &is_binary/1)

  defp valid_array_choices?(%{"anyOf" => choices}) when is_list(choices),
    do: Enum.all?(choices, &valid_titled_choice?/1)

  defp valid_array_choices?(_items), do: false

  defp valid_titled_choice?(%{"const" => value, "title" => title}),
    do: is_binary(value) and is_binary(title)

  defp valid_titled_choice?(_choice), do: false

  defp valid_sampling_params?(%{"messages" => messages, "maxTokens" => max_tokens} = params)
       when is_list(messages) and is_integer(max_tokens) do
    Enum.all?(messages, &valid_sampling_message?/1) and valid_sampling_sequence?(messages) and
      valid_sampling_optional_params?(params)
  end

  defp valid_sampling_params?(_params), do: false

  defp valid_sampling_optional_params?(params) do
    all_true?([
      valid_optional_model_preferences?(params),
      optional_binary?(params, "systemPrompt"),
      optional_include_context?(params),
      optional_number?(params, "temperature"),
      optional_string_list?(params, "stopSequences"),
      optional_map?(params, "metadata"),
      valid_optional_sampling_tools?(params),
      valid_optional_tool_choice?(params)
    ])
  end

  defp valid_sampling_message?(%{"role" => role, "content" => content} = message)
       when role in ["assistant", "user"] do
    optional_metadata?(message, "_meta") and
      content
      |> List.wrap()
      |> Enum.all?(&valid_sampling_content?/1)
  end

  defp valid_sampling_message?(_message), do: false

  defp valid_sampling_content?(%{"type" => type} = content)
       when type in ["text", "image", "audio"],
       do: valid_content_block?(content)

  defp valid_sampling_content?(
         %{
           "type" => "tool_use",
           "id" => id,
           "name" => name,
           "input" => input
         } = content
       )
       when is_binary(id) and is_binary(name) and is_map(input),
       do: optional_metadata?(content, "_meta")

  defp valid_sampling_content?(
         %{
           "type" => "tool_result",
           "toolUseId" => tool_use_id,
           "content" => content
         } = result
       )
       when is_binary(tool_use_id) and is_list(content) do
    Enum.all?(content, &valid_content_block?/1) and optional_boolean?(result, "isError") and
      optional_metadata?(result, "_meta")
  end

  defp valid_sampling_content?(_content), do: false

  defp valid_sampling_sequence?(messages) do
    messages
    |> Enum.with_index()
    |> Enum.all?(fn {message, index} ->
      valid_sampling_message_position?(messages, message, index)
    end)
  end

  defp valid_sampling_message_position?(messages, %{"role" => "assistant"} = message, index) do
    result_ids = sampling_ids(message, "tool_result", "toolUseId")
    use_ids = sampling_ids(message, "tool_use", "id")

    case {result_ids, use_ids} do
      {[_ | _], _uses} -> false
      {[], []} -> true
      {[], uses} -> matching_tool_message?(Enum.at(messages, index + 1), "user", uses)
    end
  end

  defp valid_sampling_message_position?(messages, %{"role" => "user"} = message, index) do
    use_ids = sampling_ids(message, "tool_use", "id")
    result_ids = sampling_ids(message, "tool_result", "toolUseId")

    case {use_ids, result_ids} do
      {[_ | _], _results} -> false
      {[], []} -> true
      {[], results} -> matching_tool_message?(Enum.at(messages, index - 1), "assistant", results)
    end
  end

  defp matching_tool_message?(%{"role" => role} = message, role, expected_ids) do
    actual_ids =
      sampling_ids(message, "tool_use", "id") ++ sampling_ids(message, "tool_result", "toolUseId")

    content_count = message["content"] |> List.wrap() |> length()

    length(actual_ids) == content_count and unique_ids?(actual_ids) and unique_ids?(expected_ids) and
      Enum.sort(actual_ids) == Enum.sort(expected_ids)
  end

  defp matching_tool_message?(_message, _role, _expected_ids), do: false

  defp unique_ids?(ids), do: MapSet.size(MapSet.new(ids)) == length(ids)

  defp sampling_ids(message, type, id_key) do
    message["content"]
    |> List.wrap()
    |> Enum.flat_map(fn
      %{"type" => ^type, ^id_key => id} -> [id]
      _content -> []
    end)
  end

  defp valid_optional_sampling_tools?(params) do
    case Map.fetch(params, "tools") do
      :error -> true
      {:ok, tools} when is_list(tools) -> Enum.all?(tools, &valid_tool?/1)
      {:ok, _tools} -> false
    end
  end

  defp valid_optional_model_preferences?(params) do
    case Map.fetch(params, "modelPreferences") do
      :error -> true
      {:ok, preferences} when is_map(preferences) -> valid_model_preferences?(preferences)
      {:ok, _preferences} -> false
    end
  end

  defp valid_model_preferences?(preferences) do
    valid_optional_model_hints?(preferences) and optional_priority?(preferences, "costPriority") and
      optional_priority?(preferences, "intelligencePriority") and
      optional_priority?(preferences, "speedPriority")
  end

  defp valid_optional_model_hints?(preferences) do
    case Map.fetch(preferences, "hints") do
      :error -> true
      {:ok, hints} when is_list(hints) -> Enum.all?(hints, &valid_model_hint?/1)
      {:ok, _hints} -> false
    end
  end

  defp valid_model_hint?(hint) when is_map(hint), do: optional_binary?(hint, "name")
  defp valid_model_hint?(_hint), do: false

  defp valid_optional_tool_choice?(params) do
    case Map.fetch(params, "toolChoice") do
      :error -> true
      {:ok, choice} when is_map(choice) -> optional_tool_choice_mode?(choice)
      {:ok, _choice} -> false
    end
  end

  defp optional_tool_choice_mode?(choice) do
    case Map.fetch(choice, "mode") do
      :error -> true
      {:ok, mode} -> mode in ["auto", "none", "required"]
    end
  end

  defp optional_include_context?(params) do
    case Map.fetch(params, "includeContext") do
      :error -> true
      {:ok, context} -> context in ["allServers", "none", "thisServer"]
    end
  end

  defp optional_format?(schema) do
    case Map.fetch(schema, "format") do
      :error -> true
      {:ok, format} -> format in ["date", "date-time", "email", "uri"]
    end
  end

  defp valid_content_block?(%{"type" => "text", "text" => text} = block)
       when is_binary(text),
       do: valid_content_block_fields?(block)

  defp valid_content_block?(%{"type" => "image"} = block), do: valid_media_block?(block)
  defp valid_content_block?(%{"type" => "audio"} = block), do: valid_media_block?(block)

  defp valid_content_block?(%{"type" => "resource_link"} = block) do
    all_true?([
      is_binary(block["name"]),
      is_binary(block["uri"]),
      valid_uri?(block["uri"]),
      valid_content_block_fields?(block),
      optional_integer?(block, "size"),
      optional_binary?(block, "title"),
      optional_binary?(block, "description"),
      optional_binary?(block, "mimeType"),
      valid_optional_icons?(block, "icons")
    ])
  end

  defp valid_content_block?(%{"type" => "resource", "resource" => resource} = block)
       when is_map(resource) do
    all_true?([valid_embedded_resource?(resource), valid_content_block_fields?(block)])
  end

  defp valid_content_block?(_block), do: false

  defp valid_media_block?(block) do
    all_true?([
      is_binary(block["data"]),
      is_binary(block["mimeType"]),
      valid_base64?(block["data"]),
      valid_content_block_fields?(block)
    ])
  end

  defp valid_content_block_fields?(block) do
    all_true?([
      optional_metadata?(block, "_meta"),
      valid_annotations?(Map.get(block, "annotations"))
    ])
  end

  defp valid_embedded_resource?(%{"text" => text} = resource) when is_binary(text) do
    all_true?([
      is_binary(resource["uri"]),
      valid_uri?(resource["uri"]),
      optional_binary?(resource, "mimeType"),
      optional_metadata?(resource, "_meta")
    ])
  end

  defp valid_embedded_resource?(%{"blob" => blob} = resource) when is_binary(blob) do
    all_true?([
      is_binary(resource["uri"]),
      valid_uri?(resource["uri"]),
      valid_base64?(blob),
      optional_binary?(resource, "mimeType"),
      optional_metadata?(resource, "_meta")
    ])
  end

  defp valid_embedded_resource?(_resource), do: false

  defp valid_base64?(value) when is_binary(value) do
    case ModelContextProtocol.BoundedBase64.decode(value, 8_388_608) do
      {:ok, _decoded} -> true
      {:error, _reason} -> false
    end
  end

  defp valid_base64?(_value), do: false

  defp valid_uri?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) -> true
      {:ok, %URI{scheme: nil}} -> false
      {:error, _part} -> false
    end
  end

  defp valid_uri?(_value), do: false

  defp all_true?(values), do: Enum.all?(values, & &1)

  defp valid_annotations?(nil), do: true

  defp valid_annotations?(annotations) when is_map(annotations) do
    optional_audience?(annotations) and optional_priority?(annotations) and
      optional_binary?(annotations, "lastModified")
  end

  defp valid_annotations?(_annotations), do: false

  defp optional_audience?(annotations) do
    case Map.fetch(annotations, "audience") do
      :error ->
        true

      {:ok, audience} when is_list(audience) ->
        Enum.all?(audience, &(&1 in ["assistant", "user"]))

      {:ok, _audience} ->
        false
    end
  end

  defp optional_priority?(annotations) do
    case Map.fetch(annotations, "priority") do
      :error -> true
      {:ok, priority} when is_number(priority) -> priority >= 0 and priority <= 1
      {:ok, _priority} -> false
    end
  end

  defp optional_priority?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, priority} when is_number(priority) -> priority >= 0 and priority <= 1
      {:ok, _priority} -> false
    end
  end

  defp validate_optional_result_meta(result) do
    case Map.fetch(result, "_meta") do
      :error ->
        :ok

      {:ok, metadata} ->
        case valid_metadata?(metadata) and valid_server_info?(metadata) do
          true -> :ok
          false -> {:error, :invalid_result_meta}
        end
    end
  end

  defp valid_server_info?(metadata) do
    case Map.fetch(metadata, "io.modelcontextprotocol/serverInfo") do
      :error ->
        true

      {:ok, %{"name" => name, "version" => version} = server_info} ->
        is_binary(name) and is_binary(version) and optional_binary?(server_info, "title") and
          optional_binary?(server_info, "description") and
          optional_binary?(server_info, "websiteUrl") and
          valid_optional_icons?(server_info, "icons")

      {:ok, _server_info} ->
        false
    end
  end

  defp valid_optional_icons?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, icons} when is_list(icons) -> Enum.all?(icons, &valid_icon?/1)
      {:ok, _icons} -> false
    end
  end

  defp valid_icon?(%{"src" => source} = icon) when is_binary(source) do
    optional_binary?(icon, "mimeType") and optional_string_list?(icon, "sizes") and
      optional_theme?(icon)
  end

  defp valid_icon?(_icon), do: false

  defp optional_string_list?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, values} when is_list(values) -> Enum.all?(values, &is_binary/1)
      {:ok, _values} -> false
    end
  end

  defp optional_theme?(icon) do
    case Map.fetch(icon, "theme") do
      :error -> true
      {:ok, theme} -> theme in ["dark", "light"]
    end
  end

  defp validate_optional_string(map, key) do
    case optional_binary?(map, key) do
      true -> :ok
      false -> {:error, :invalid_optional_string}
    end
  end

  defp optional_metadata?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, metadata} -> valid_metadata?(metadata)
    end
  end

  defp valid_metadata?(metadata)
       when is_map(metadata) and map_size(metadata) <= @metadata_keys_max do
    Enum.all?(Map.keys(metadata), &valid_metadata_key?/1) and
      metadata_bytes(metadata) <= @metadata_bytes_max
  end

  defp valid_metadata?(_metadata), do: false

  defp valid_metadata_key?(key) when is_binary(key),
    do: key not in @reserved_metadata_keys and Regex.match?(@metadata_key_regex, key)

  defp valid_metadata_key?(_key), do: false

  defp metadata_bytes(metadata), do: metadata |> Jason.encode!() |> byte_size()

  defp named_error?(%{"code" => code, "message" => message}, expected_code),
    do: code == expected_code and is_binary(message)

  defp named_error?(_error, _expected_code), do: false

  defp valid_named_error?(%{"code" => @error_missing_required_client_capability} = error) do
    match?(%{"requiredCapabilities" => capabilities} when is_map(capabilities), error["data"])
  end

  defp valid_named_error?(%{"code" => @error_unsupported_protocol_version} = error) do
    case error["data"] do
      %{"requested" => requested, "supported" => supported}
      when is_binary(requested) and is_list(supported) ->
        Enum.all?(supported, &is_binary/1)

      _data ->
        false
    end
  end

  defp valid_named_error?(%{"code" => @error_header_mismatch}), do: true
  defp valid_named_error?(_error), do: true

  defp optional_boolean?(map, key), do: not Map.has_key?(map, key) or is_boolean(map[key])
  defp optional_map?(map, key), do: not Map.has_key?(map, key) or is_map(map[key])
  defp optional_binary?(map, key), do: not Map.has_key?(map, key) or is_binary(map[key])
  defp optional_integer?(map, key), do: not Map.has_key?(map, key) or is_integer(map[key])
  defp optional_number?(map, key), do: not Map.has_key?(map, key) or is_number(map[key])

  defp optional_non_negative_integer?(map, key),
    do: not Map.has_key?(map, key) or (is_integer(map[key]) and map[key] >= 0)

  defp complete_result(content, is_error) do
    %{"resultType" => "complete", "content" => content, "isError" => is_error}
  end
end
