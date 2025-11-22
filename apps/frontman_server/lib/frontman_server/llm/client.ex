defmodule FrontmanServer.LLM.Client do
  @moduledoc """
  Client for LLM API interactions using req_llm.

  Low-level interface to the LLM API. Does not know about domain concepts
  like Interactions or Tasks.
  """
  require Logger

  @doc """
  Generate a streaming response from the LLM.

  Accepts messages in req_llm format (built with ReqLLM.Context functions).
  Returns a stream of tokens that can be consumed.

  ## Options
  - `:model` - Model to use (default: "openai:gpt-4o-mini")
  - `:fixture_path` - Path to fixture file for testing (record/replay)
  """
  def stream_chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "openai:gpt-4o-mini")
    api_key = get_api_key(model)

    llm_opts = [api_key: api_key]

    # Add fixture_path if provided (for testing)
    llm_opts =
      case Keyword.get(opts, :fixture_path) do
        nil -> llm_opts
        fixture_path -> Keyword.put(llm_opts, :fixture_path, fixture_path)
      end

    case ReqLLM.stream_text(model, messages, llm_opts) do
      {:ok, response} ->
        {:ok, ReqLLM.StreamResponse.tokens(response)}

      error ->
        Logger.error("LLM call failed: #{inspect(error)}")
        error
    end
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
