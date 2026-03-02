defmodule FrontmanServer.Tasks.Execution.LLMClient do
  @moduledoc """
  SwarmAi.LLM implementation using ReqLLM.

  Stream-first design: returns a lazy stream of chunks that can be
  consumed with callbacks or collected into a Response.

  API key resolution happens at the domain layer (Tasks context) before
  this client is created. The resolved key is passed via `llm_opts[:api_key]`.
  """

  @default_model "openrouter:openai/gpt-5.1-codex"

  use TypedStruct

  alias SwarmAi.SchemaTransformer

  typedstruct do
    field(:model, String.t(), default: @default_model)
    field(:tools, [SwarmAi.Tool.t()], default: [])
    # llm_opts must include :api_key (resolved at domain layer)
    field(:llm_opts, keyword(), default: [])
  end

  @doc """
  Returns the default model.
  """
  def default_model, do: @default_model

  @doc """
  Creates a new LLMClient.

  ## Options

  - `:model` - Model spec string (default: "openrouter:openai/gpt-5.1-codex")
  - `:tools` - List of SwarmAi.Tool structs
  - `:llm_opts` - Options for ReqLLM, must include `:api_key`
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Converts SwarmAi.Tool to ReqLLM.Tool format.
  Normalizes schemas for OpenAI-compatible providers that require strict mode.

  When `requires_mcp_prefix: true` is passed in opts, tool names are prefixed with `mcp_`.
  """
  @spec to_reqllm_tool(SwarmAi.Tool.t(), String.t(), keyword()) :: ReqLLM.Tool.t()
  def to_reqllm_tool(%SwarmAi.Tool{} = tool, model, opts \\ []) do
    provider = SchemaTransformer.provider_for_model(model)
    schema = SchemaTransformer.transform(tool.parameter_schema, provider)
    strict? = provider == :openai_strict

    requires_mcp_prefix? = Keyword.get(opts, :requires_mcp_prefix, false)

    # Prefix tool name with mcp_ when required (e.g., Claude Code OAuth)
    name = if requires_mcp_prefix?, do: "mcp_#{tool.name}", else: tool.name

    ReqLLM.Tool.new!(
      name: name,
      description: tool.description,
      parameter_schema: schema,
      strict: strict?,
      callback: fn _args -> {:ok, nil} end
    )
  end

  @doc """
  Returns true if the llm_opts require mcp_ prefix on tool names.
  """
  def requires_mcp_prefix?(llm_opts) do
    Keyword.get(llm_opts, :requires_mcp_prefix, false)
  end

  @doc """
  Strips the mcp_ prefix from a tool name if present.
  """
  def strip_mcp_prefix("mcp_" <> rest), do: rest
  def strip_mcp_prefix(name), do: name
end

defimpl SwarmAi.LLM, for: FrontmanServer.Tasks.Execution.LLMClient do
  alias FrontmanServer.Tasks.Execution.LLMClient
  alias FrontmanServer.Tasks.StreamCleanup
  alias SwarmAi.LLM.{Chunk, Usage}
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart
  alias SwarmAi.SchemaTransformer
  alias SwarmAi.ToolCall

  require Logger

  def stream(client, messages, _opts) do
    requires_mcp_prefix? = LLMClient.requires_mcp_prefix?(client.llm_opts)
    identity_override = Keyword.get(client.llm_opts, :identity_override)

    # Convert tools, applying mcp_ prefix if required
    reqllm_tools =
      Enum.map(client.tools, &LLMClient.to_reqllm_tool(&1, client.model, client.llm_opts))

    # API key must be provided via llm_opts (resolved at domain layer)
    llm_opts =
      client.llm_opts
      |> Keyword.put_new(:tools, reqllm_tools)
      |> Keyword.reject(fn {_k, v} -> v == [] end)

    # Convert messages, applying mcp_ prefix to tool names if required
    # For OAuth with identity_override, prepend identity as first content block
    reqllm_messages =
      messages
      |> Enum.map(&to_reqllm_message(&1, requires_mcp_prefix?))
      |> maybe_prepend_identity(identity_override)

    case ReqLLM.stream_text(client.model, reqllm_messages, llm_opts) do
      {:ok, response} ->
        swarm_stream =
          response.stream
          |> Stream.map(&to_swarm_chunk(&1, requires_mcp_prefix?))
          |> Stream.reject(&is_nil/1)
          |> StreamCleanup.wrap_stream(response.cancel)

        {:ok, swarm_stream}

      {:error, reason} ->
        Logger.error("LLMClient.stream ReqLLM.stream_text failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp to_swarm_chunk(%{type: :content, text: text}, _requires_mcp_prefix?)
       when is_binary(text) do
    Chunk.token(text)
  end

  defp to_swarm_chunk(%{type: :thinking, text: text, metadata: meta}, _requires_mcp_prefix?)
       when is_binary(text) do
    Chunk.thinking(text, meta || %{})
  end

  defp to_swarm_chunk(%{type: :thinking, text: text}, _requires_mcp_prefix?)
       when is_binary(text) do
    Chunk.thinking(text)
  end

  # Handle tool call chunks from ReqLLM
  # In streaming mode, ReqLLM sends tool name first (with empty args),
  # then argument fragments arrive as separate :meta chunks.
  # In non-streaming mode, the complete tool call arrives at once.
  defp to_swarm_chunk(
         %{type: :tool_call, name: name, arguments: args, metadata: meta},
         requires_mcp_prefix?
       ) do
    id = Map.get(meta, :id) || "call_#{:erlang.unique_integer([:positive])}"
    index = Map.get(meta, :index, 0)

    # Strip mcp_ prefix if we added it
    name = if requires_mcp_prefix?, do: LLMClient.strip_mcp_prefix(name), else: name

    # Check if this is a complete tool call (non-streaming) or a streaming start
    is_complete = complete_tool_call_args?(args)

    if is_complete do
      # Non-streaming: emit complete tool call directly
      args_json = if is_binary(args), do: args, else: Jason.encode!(args)
      tool_call = %ToolCall{id: id, name: name, arguments: args_json}
      Chunk.tool_call_end(tool_call)
    else
      # Streaming: emit tool_call_start, arguments will follow as fragments
      Chunk.tool_call_start(id, name, index)
    end
  end

  # Handle argument fragment chunks from ReqLLM streaming
  defp to_swarm_chunk(
         %{
           type: :meta,
           metadata: %{tool_call_args: %{index: index, fragment: fragment}}
         },
         _requires_mcp_prefix?
       ) do
    Chunk.tool_call_args(index, fragment)
  end

  # :meta with usage - token usage statistics
  defp to_swarm_chunk(%{type: :meta, metadata: %{usage: usage}}, _requires_mcp_prefix?)
       when is_map(usage) do
    Chunk.usage(%Usage{
      input_tokens: Map.get(usage, :input_tokens, 0),
      output_tokens: Map.get(usage, :output_tokens, 0),
      reasoning_tokens: Map.get(usage, :reasoning_tokens, 0),
      cached_tokens: Map.get(usage, :cached_tokens, 0)
    })
  end

  # :meta with finish_reason - stream complete with reason
  # Carry through response_id for Responses API previous_response_id chaining.
  # Only response_id is extracted — it's the only metadata Chunk.done consumers use
  # (for previous_response_id chaining in subsequent Responses API calls).
  # When absent (e.g. Anthropic, Chat Completions API), we pass an empty map
  # since those providers don't support response chaining.
  defp to_swarm_chunk(
         %{type: :meta, metadata: %{finish_reason: reason} = meta},
         _requires_mcp_prefix?
       ) do
    chunk_meta =
      case meta do
        %{response_id: id} when is_binary(id) -> %{response_id: id}
        _ -> %{}
      end

    Chunk.done(reason, chunk_meta)
  end

  # :meta with terminal?: true only (no finish_reason) - message_stop signal
  # This comes from Anthropic's message_stop event, signals end of message
  defp to_swarm_chunk(%{type: :meta, metadata: %{terminal?: true}}, _requires_mcp_prefix?) do
    # Emit done with :stop as default finish reason
    Chunk.done(:stop)
  end

  # Catch-all for :meta chunks with unknown metadata keys
  # These are informational signals we don't need to act on (e.g., provider-specific metadata)
  # Silently ignore - we're resilient to new metadata fields
  defp to_swarm_chunk(%{type: :meta, metadata: _meta}, _requires_mcp_prefix?) do
    nil
  end

  # Stream-level provider/API error chunk emitted by ReqLLM.
  # The raise propagates through Response.from_stream → Task crash →
  # ExecutionMonitor → {:agent_error, message} → TaskChannel → client ErrorBanner.
  #
  # ReqLLM StreamChunk error shape: %{type: :error, text: message, metadata: %{error: original}}
  # where `original` is typically a ReqLLM.Error.API.Request with :status and :reason fields.
  # We classify by HTTP status to produce user-friendly messages.
  defp to_swarm_chunk(
         %{type: :error, text: text, metadata: %{error: original}},
         _requires_mcp_prefix?
       )
       when is_binary(text) do
    raise classify_llm_error(original, text)
  end

  defp to_swarm_chunk(%{type: :error, text: text}, _requires_mcp_prefix?)
       when is_binary(text) do
    raise classify_llm_error(nil, text)
  end

  defp to_swarm_chunk(%{type: :error} = chunk, _requires_mcp_prefix?) do
    raise "LLM stream error: #{inspect(chunk, limit: :infinity)}"
  end

  # CRASH on truly unknown chunk TYPES (not :content, :thinking, :tool_call, :meta, or :error)
  # This catches bugs where ReqLLM adds new types we don't handle
  defp to_swarm_chunk(%{type: unknown_type} = chunk, _requires_mcp_prefix?)
       when unknown_type not in [:content, :thinking, :tool_call, :meta, :error] do
    raise "Unknown chunk TYPE from ReqLLM: #{inspect(unknown_type)}. " <>
            "Full chunk: #{inspect(chunk, limit: :infinity)}"
  end

  # Catch-all for malformed chunks (missing type field or unexpected structure)
  defp to_swarm_chunk(malformed_chunk, _requires_mcp_prefix?) do
    raise "Malformed chunk from ReqLLM (missing or invalid type): #{inspect(malformed_chunk, limit: :infinity)}"
  end

  # Check if tool call arguments are complete (non-streaming)
  defp complete_tool_call_args?(args) when is_map(args) and map_size(args) > 0, do: true
  defp complete_tool_call_args?(args) when is_binary(args) and args not in ["", "{}"], do: true
  defp complete_tool_call_args?(_), do: false

  # Classify LLM API errors by HTTP status into user-friendly messages.
  # The original error is a ReqLLM.Error.API.Request with :status and :reason.
  defp classify_llm_error(%{status: status}, _text) when status in [401, 403] do
    "Authentication failed — your API key may be invalid or expired (HTTP #{status})"
  end

  defp classify_llm_error(%{status: 400, reason: reason}, _text) when is_binary(reason) do
    "Bad request — the provider rejected the request: #{reason}"
  end

  defp classify_llm_error(%{status: 400}, text) do
    "Bad request — the provider rejected the request: #{text}"
  end

  defp classify_llm_error(%{status: 402}, _text) do
    "Payment required — your account balance is insufficient or billing is not configured (HTTP 402)"
  end

  defp classify_llm_error(%{status: 413}, _text) do
    "Payload too large — the request exceeded the provider's size limit. Try reducing image size or message length (HTTP 413)"
  end

  defp classify_llm_error(%{status: 429}, _text) do
    "Rate limited — the provider is throttling requests. Please try again shortly."
  end

  defp classify_llm_error(%{status: status}, _text) when status >= 500 do
    "Provider error — the LLM service returned an internal error (HTTP #{status}). Please try again."
  end

  defp classify_llm_error(%{status: status, reason: reason}, _text)
       when is_integer(status) and is_binary(reason) do
    "LLM error (HTTP #{status}): #{reason}"
  end

  defp classify_llm_error(_, text) do
    "LLM stream error: #{text}"
  end

  # Prepend identity override as the first content block of system messages
  # This is used for Claude Code OAuth to inject "You are Claude Code..." identity
  defp maybe_prepend_identity(messages, nil), do: messages

  defp maybe_prepend_identity(messages, identity) when is_binary(identity) do
    Enum.map(messages, fn
      %ReqLLM.Message{role: :system, content: content} = msg ->
        identity_part = ReqLLM.Message.ContentPart.text(identity)
        %{msg | content: [identity_part | content]}

      msg ->
        msg
    end)
  end

  # --- SwarmAi.Message -> ReqLLM.Message conversion ---

  defp to_reqllm_message(%Message{} = msg, requires_mcp_prefix?) do
    %ReqLLM.Message{
      role: msg.role,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_calls: to_reqllm_tool_calls(msg.tool_calls, requires_mcp_prefix?),
      tool_call_id: msg.tool_call_id,
      name: maybe_prefix_name(msg.name, requires_mcp_prefix?),
      metadata: msg.metadata || %{}
    }
  end

  defp to_reqllm_content_part(%ContentPart{type: :text, text: text}) do
    ReqLLM.Message.ContentPart.text(text)
  end

  defp to_reqllm_content_part(%ContentPart{type: :image, data: data, media_type: mt}) do
    ReqLLM.Message.ContentPart.image(data, mt)
  end

  defp to_reqllm_content_part(%ContentPart{type: :image_url, url: url}) do
    ReqLLM.Message.ContentPart.image_url(url)
  end

  defp to_reqllm_tool_calls([], _requires_mcp_prefix?), do: nil
  defp to_reqllm_tool_calls(nil, _requires_mcp_prefix?), do: nil

  defp to_reqllm_tool_calls(tool_calls, requires_mcp_prefix?) do
    Enum.map(tool_calls, fn tc ->
      name = if requires_mcp_prefix?, do: "mcp_#{tc.name}", else: tc.name
      arguments = strip_null_args(tc.arguments)
      ReqLLM.ToolCall.new(tc.id, name, arguments)
    end)
  end

  # Strip null values from tool call arguments in conversation history.
  # OpenAI strict mode makes optional fields nullable, so the model sends null.
  # Clean these before sending back in the next turn.
  defp strip_null_args(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, args} when is_map(args) ->
        Jason.encode!(SwarmAi.SchemaTransformer.strip_nulls(args))

      _ ->
        arguments
    end
  end

  defp strip_null_args(arguments), do: arguments

  # Prefix tool name in tool result messages if mcp_ prefix is required
  defp maybe_prefix_name(nil, _requires_mcp_prefix?), do: nil
  defp maybe_prefix_name(name, true), do: "mcp_#{name}"
  defp maybe_prefix_name(name, false), do: name
end
