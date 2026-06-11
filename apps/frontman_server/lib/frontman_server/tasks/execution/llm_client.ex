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

  Provider auth resolution happens at the domain layer (Tasks context) before
  this client is created. The resolved ReqLLM options are passed via `llm_opts`.
  """

  alias SwarmAi.SchemaTransformer

  # Provider auth options are resolved at the domain layer.
  @enforce_keys [:model]
  defstruct model: nil,
            tools: [],
            llm_opts: []

  @doc """
  Creates a new LLMClient.

  ## Options

  - `:model` - Required ReqLLM model spec from `Providers.prepare_llm_args/3`
  - `:tools` - List of SwarmAi.Tool structs
  - `:llm_opts` - Options for ReqLLM, including resolved provider auth
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Converts SwarmAi.Tool to ReqLLM.Tool format.
  Normalizes schemas for OpenAI-compatible providers that require strict mode.
  """
  def to_reqllm_tool(%SwarmAi.Tool{} = tool, model, _opts \\ []) do
    provider = SchemaTransformer.provider_for_model(model)
    schema = SchemaTransformer.transform(tool.parameter_schema, provider)
    strict? = provider == :openai_strict

    ReqLLM.Tool.new!(
      name: tool.name,
      description: tool.description,
      parameter_schema: schema,
      strict: strict?,
      callback: fn _args -> {:ok, nil} end
    )
  end
end

defimpl SwarmAi.LLM, for: FrontmanServer.Tasks.Execution.LLMClient do
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.LLMClient
  alias FrontmanServer.Tasks.Execution.LLMProvider
  alias FrontmanServer.Tasks.Execution.LLMRequestPreflight
  alias FrontmanServer.Tasks.{StreamCleanup, StreamStallTimeout}
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  require Logger

  def stream(client, messages, _opts) do
    reqllm_tools =
      Enum.map(client.tools, &LLMClient.to_reqllm_tool(&1, client.model, client.llm_opts))

    # Provider auth must be provided via llm_opts (resolved at domain layer)
    llm_opts =
      client.llm_opts
      |> Keyword.put_new(:tools, reqllm_tools)
      |> Keyword.reject(fn
        {:parallel_tool_calls, _value} -> true
        {_key, value} -> value == []
      end)

    provider = Providers.model_provider_name(client.model)

    preflight_opts = [
      images_supported: images_supported?(client.model),
      llm_vendor: Providers.model_llm_vendor_name(client.model),
      max_image_dimension: Providers.max_image_dimension(provider)
    ]

    # Run request preflight here (not just at task startup) so that tool results
    # accumulated inside the swarm loop are also truncated. Without this, long
    # tool-calling chains accumulate dozens of full-size tool results and the
    # request body grows until Anthropic closes the connection.
    reqllm_messages =
      messages
      |> LLMRequestPreflight.run(preflight_opts)
      |> Enum.map(&to_reqllm_message/1)

    case LLMProvider.stream_text(
           client.model,
           reqllm_messages,
           llm_opts
         ) do
      {:ok, response} ->
        stall_timeout_ms =
          Application.fetch_env!(:frontman_server, :stream_stall_timeout_ms)

        reqllm_stream =
          response.stream
          |> StreamStallTimeout.wrap_stream(stall_timeout_ms: stall_timeout_ms)
          |> Stream.map(&normalize_reqllm_chunk/1)
          |> StreamCleanup.wrap_stream(response.cancel)

        {:ok, reqllm_stream}

      {:error, reason} ->
        Logger.error("LLMClient.stream ReqLLM.stream_text failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp normalize_reqllm_chunk(%{type: :content} = chunk) do
    chunk
  end

  defp normalize_reqllm_chunk(%{type: :thinking} = chunk) do
    chunk
  end

  defp normalize_reqllm_chunk(
         %{type: :tool_call, arguments: arguments, metadata: metadata} = chunk
       ) do
    metadata = metadata || %{}

    id = metadata[:id] || metadata["id"] || "call_#{:erlang.unique_integer([:positive])}"

    index = normalize_index(metadata[:index] || metadata["index"])

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
      | arguments: normalized_arguments,
        metadata: normalized_metadata
    }
  end

  defp normalize_reqllm_chunk(%{type: :meta} = chunk) do
    chunk
  end

  defp images_supported?(model) do
    case ReqLLM.model(model) do
      {:ok, %{modalities: %{input: input}}} when is_list(input) -> :image in input
      _ -> true
    end
  end

  defp normalize_index(index) when is_integer(index), do: index

  defp normalize_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, ""} -> value
      _other -> 0
    end
  end

  defp normalize_index(_index), do: 0

  # --- SwarmAi.Message -> ReqLLM.Message conversion ---

  defp to_reqllm_message(%Message.System{} = msg) do
    %ReqLLM.Message{role: :system, content: Enum.map(msg.content, &to_reqllm_content_part/1)}
  end

  defp to_reqllm_message(%Message.User{} = msg) do
    %ReqLLM.Message{role: :user, content: Enum.map(msg.content, &to_reqllm_content_part/1)}
  end

  defp to_reqllm_message(%Message.Assistant{} = msg) do
    %ReqLLM.Message{
      role: :assistant,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_calls: to_reqllm_tool_calls(msg.tool_calls),
      metadata: msg.metadata,
      reasoning_details: msg.reasoning_details
    }
  end

  defp to_reqllm_message(%Message.Tool{} = msg) do
    %ReqLLM.Message{
      role: :tool,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_call_id: msg.tool_call_id,
      name: msg.name,
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

  defp to_reqllm_tool_calls([]), do: nil
  defp to_reqllm_tool_calls(nil), do: nil

  defp to_reqllm_tool_calls(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      tc = SwarmAi.ToolCall.strip_null_arguments(tc)
      ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
    end)
  end
end
