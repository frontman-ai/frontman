defmodule FrontmanServer.LLM.Client do
  @moduledoc """
  Client for LLM API interactions using req_llm.

  Low-level interface to the LLM API. Does not know about domain concepts
  like Interactions or Tasks. Supports both simple streaming and tool-enabled
  streaming.
  """
  require Logger

  @default_model "anthropic:claude-sonnet-4-20250514"

  @doc """
  Generate a streaming response from the LLM with optional tool support.

  Returns a stream of chunks that may contain text and/or tool calls.

  ## Options
  - `:model` - Model to use (default: "#{@default_model}")
  - `:tools` - List of ReqLLM.Tool structs (default: [])
  - `:fixture_path` - Path to fixture file for testing (record/replay)
  """
  def stream_chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    tools = Keyword.get(opts, :tools, [])
    api_key = get_api_key(model)

    llm_opts = [api_key: api_key]

    llm_opts =
      case Keyword.get(opts, :fixture_path) do
        nil -> llm_opts
        fixture_path -> Keyword.put(llm_opts, :fixture_path, fixture_path)
      end

    llm_opts =
      case tools do
        [] -> llm_opts
        tools -> Keyword.put(llm_opts, :tools, tools)
      end

    case ReqLLM.stream_text(model, messages, llm_opts) do
      {:ok, response} ->
        {:ok, response.stream}

      error ->
        Logger.error("LLM call failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Extracts tool calls from a list of chunks.

  Handles fragmented JSON arguments that may be spread across multiple chunks.
  Returns a list of maps with :id, :name, and :arguments keys.
  """
  def extract_tool_calls(chunks) do
    tool_calls =
      chunks
      |> Enum.filter(&(&1.type == :tool_call))
      |> Enum.map(fn chunk ->
        %{
          id: Map.get(chunk.metadata, :id) || "call_#{:erlang.unique_integer([:positive])}",
          name: chunk.name,
          arguments: chunk.arguments || %{},
          index: Map.get(chunk.metadata, :index, 0)
        }
      end)

    arg_fragments =
      chunks
      |> Enum.filter(fn
        %{type: :meta, metadata: %{tool_call_args: _}} -> true
        _ -> false
      end)
      |> Enum.group_by(& &1.metadata.tool_call_args.index)
      |> Map.new(fn {index, fragments} ->
        json = fragments |> Enum.map_join("", & &1.metadata.tool_call_args.fragment)
        {index, json}
      end)

    tool_calls
    |> Enum.map(fn call ->
      case Map.get(arg_fragments, call.index) do
        nil ->
          Map.delete(call, :index)

        json ->
          case Jason.decode(json) do
            {:ok, args} -> call |> Map.put(:arguments, args) |> Map.delete(:index)
            {:error, _} -> Map.delete(call, :index)
          end
      end
    end)
  end

  @doc """
  Extracts the accumulated text from chunks.
  """
  def extract_text(chunks) do
    chunks
    |> Enum.map_join("", fn chunk -> chunk.text || "" end)
  end

  defp get_api_key(model) do
    cond do
      String.starts_with?(model, "openai:") ->
        Application.get_env(:frontman_server, :openai_api_key)

      String.starts_with?(model, "anthropic:") ->
        Application.get_env(:frontman_server, :anthropic_api_key)

      true ->
        Application.get_env(:frontman_server, :anthropic_api_key)
    end
  end
end
