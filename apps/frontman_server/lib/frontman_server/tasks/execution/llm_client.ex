# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.LLMClient do
  @moduledoc """
  SwarmAi.LLM implementation using ReqLLM.

  Stream-first design: returns a lazy stream of chunks that can be
  consumed with callbacks or collected into a Response.

  API key resolution happens at the domain layer (Tasks context) before
  this client is created. The resolved key is passed via `llm_opts[:api_key]`.
  """

  use TypedStruct

  alias FrontmanServer.Providers
  alias SwarmAi.SchemaTransformer

  typedstruct do
    field(:model, String.t(), default: Providers.default_model())
    field(:tools, [SwarmAi.Tool.t()], default: [])
    # llm_opts must include :api_key (resolved at domain layer)
    field(:llm_opts, keyword(), default: [])
  end

  @doc """
  Creates a new LLMClient.

  ## Options

  - `:model` - Model spec string (default: "openrouter:google/gemini-3-flash-preview")
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
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.{MessageOptimizer, StreamCleanup, StreamStallTimeout}
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart
  alias SwarmAi.SchemaTransformer

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
      |> Keyword.put_new(:parallel_tool_calls, true)
      |> Keyword.reject(fn {_k, v} -> v == [] end)

    # Convert messages, applying mcp_ prefix to tool names if required
    # For OAuth with identity_override, prepend identity as first content block.
    # Run MessageOptimizer here (not just at task startup) so that tool results
    # accumulated inside the swarm loop are also truncated. Without this, long
    # tool-calling chains accumulate dozens of full-size tool results and the
    # request body grows until Anthropic closes the connection.
    reqllm_messages =
      messages
      |> Enum.map(&to_reqllm_message(&1, requires_mcp_prefix?))
      |> maybe_prepend_identity(identity_override)
      |> MessageOptimizer.optimize()

    case ReqLLM.stream_text(client.model, reqllm_messages, llm_opts) do
      {:ok, response} ->
        stall_timeout_ms =
          Application.fetch_env!(:frontman_server, :stream_stall_timeout_ms)

        reqllm_stream =
          response.stream
          |> StreamStallTimeout.wrap_stream(stall_timeout_ms: stall_timeout_ms)
          |> Stream.map(&normalize_reqllm_chunk(&1, requires_mcp_prefix?))
          |> StreamCleanup.wrap_stream(response.cancel)

        {:ok, reqllm_stream}

      {:error, reason} ->
        Logger.error("LLMClient.stream ReqLLM.stream_text failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp normalize_reqllm_chunk(%{type: :content} = chunk, _requires_mcp_prefix?) do
    chunk
  end

  defp normalize_reqllm_chunk(%{type: :thinking} = chunk, _requires_mcp_prefix?) do
    chunk
  end

  defp normalize_reqllm_chunk(
         %{type: :tool_call, name: name, arguments: arguments, metadata: metadata} = chunk,
         requires_mcp_prefix?
       ) do
    metadata = metadata || %{}

    id = metadata[:id] || metadata["id"] || "call_#{:erlang.unique_integer([:positive])}"

    index = normalize_index(metadata[:index] || metadata["index"])

    normalized_name =
      if requires_mcp_prefix? and is_binary(name),
        do: LLMClient.strip_mcp_prefix(name),
        else: name

    normalized_arguments =
      case arguments do
        nil -> %{}
        _ -> arguments
      end

    normalized_metadata =
      metadata
      |> Map.put(:id, id)
      |> Map.put(:index, index)

    %{
      chunk
      | name: normalized_name,
        arguments: normalized_arguments,
        metadata: normalized_metadata
    }
  end

  defp normalize_reqllm_chunk(%{type: :meta} = chunk, _requires_mcp_prefix?) do
    chunk
  end

  # Legacy compatibility path for ReqLLM builds that emit :error chunks.
  # Current ReqLLM versions raise ReqLLM.Error.API.Stream instead; those are
  # classified in ExecutionEvent.classify_error/1.
  defp normalize_reqllm_chunk(
         %{type: :error, text: text, metadata: %{error: original}},
         _requires_mcp_prefix?
       )
       when is_binary(text) do
    classify_llm_error(original, text)
  end

  defp normalize_reqllm_chunk(%{type: :error, text: text}, _requires_mcp_prefix?)
       when is_binary(text) do
    classify_llm_error(nil, text)
  end

  defp normalize_reqllm_chunk(%{type: :error} = chunk, _requires_mcp_prefix?) do
    raise "LLM stream error: #{inspect(chunk, limit: :infinity)}"
  end

  defp normalize_reqllm_chunk(%{type: unknown_type} = chunk, _requires_mcp_prefix?)
       when unknown_type not in [:content, :thinking, :tool_call, :meta, :error] do
    raise "Unknown chunk TYPE from ReqLLM: #{inspect(unknown_type)}. " <>
            "Full chunk: #{inspect(chunk, limit: :infinity)}"
  end

  defp normalize_reqllm_chunk(malformed_chunk, _requires_mcp_prefix?) do
    raise "Malformed chunk from ReqLLM (missing or invalid type): #{inspect(malformed_chunk, limit: :infinity)}"
  end

  defp normalize_index(index) when is_integer(index), do: index

  defp normalize_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, ""} -> value
      _other -> 0
    end
  end

  defp normalize_index(_index), do: 0

  # Classify LLM API errors by HTTP status and raise a typed LLMError.
  # The original error is a ReqLLM.Error.API.Request with :status and :reason.
  defp classify_llm_error(%{status: status}, _text) when status in [401, 403] do
    raise LLMError,
      message: "Authentication failed — your API key may be invalid or expired (HTTP #{status})",
      category: "auth",
      retryable: false
  end

  defp classify_llm_error(%{status: 400, reason: reason}, _text) when is_binary(reason) do
    raise LLMError,
      message: "Bad request — the provider rejected the request: #{reason}",
      category: "unknown",
      retryable: false
  end

  defp classify_llm_error(%{status: 400}, text) do
    raise LLMError,
      message: "Bad request — the provider rejected the request: #{text}",
      category: "unknown",
      retryable: false
  end

  defp classify_llm_error(%{status: 402}, _text) do
    raise LLMError,
      message:
        "Payment required — your account balance is insufficient or billing is not configured (HTTP 402)",
      category: "billing",
      retryable: false
  end

  defp classify_llm_error(%{status: 413}, _text) do
    raise LLMError,
      message:
        "Payload too large — the request exceeded the provider's size limit. Try reducing image size or message length (HTTP 413)",
      category: "payload_too_large",
      retryable: false
  end

  defp classify_llm_error(%{status: 429}, _text) do
    raise LLMError,
      message: "Rate limited — the provider is throttling requests. Please try again shortly.",
      category: "rate_limit",
      retryable: true
  end

  defp classify_llm_error(%{status: status}, _text) when status >= 500 do
    raise LLMError,
      message:
        "Provider error — the LLM service returned an internal error (HTTP #{status}). Please try again.",
      category: "overload",
      retryable: true
  end

  defp classify_llm_error(%{status: status, reason: reason}, _text)
       when is_integer(status) and is_binary(reason) do
    raise LLMError,
      message: "LLM error (HTTP #{status}): #{reason}",
      category: "unknown",
      retryable: false
  end

  defp classify_llm_error(_, text) do
    raise LLMError,
      message: "LLM stream error: #{text}",
      category: "unknown",
      retryable: false
  end

  # Log per-call message sizes to help diagnose large-request transport errors.
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

  defp to_reqllm_message(%Message.System{} = msg, _requires_mcp_prefix?) do
    %ReqLLM.Message{role: :system, content: Enum.map(msg.content, &to_reqllm_content_part/1)}
  end

  defp to_reqllm_message(%Message.User{} = msg, _requires_mcp_prefix?) do
    %ReqLLM.Message{role: :user, content: Enum.map(msg.content, &to_reqllm_content_part/1)}
  end

  defp to_reqllm_message(%Message.Assistant{} = msg, requires_mcp_prefix?) do
    %ReqLLM.Message{
      role: :assistant,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_calls: to_reqllm_tool_calls(msg.tool_calls, requires_mcp_prefix?),
      metadata: msg.metadata
    }
  end

  defp to_reqllm_message(%Message.Tool{} = msg, requires_mcp_prefix?) do
    %ReqLLM.Message{
      role: :tool,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_call_id: msg.tool_call_id,
      name: maybe_prefix_name(msg.name, requires_mcp_prefix?),
      metadata: msg.metadata
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
