# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution do
  @moduledoc """
  Orchestrates agent execution for tasks.

  This module handles the mechanics of running an LLM agent loop:
  - Building root agents from task data
  - Submitting agents to SwarmAi
  - Routing tool result notifications to waiting executors
  """

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.{Prompts, RootAgent}
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema, TaskSchema}
  alias SwarmAi.Message.ContentPart

  @doc """
  Runs an agent execution for a task.

  Resolves provider auth, builds the root agent from the task,
  and submits the agent to SwarmAi.

  ## Params
  - `:tools` - LLM-visible tool schemas
  - `:model` - LLM model spec (nil uses provider default)
  - `:turn_number` - turn being executed
  - `:interaction_rows` - persisted rows used to build prompt history
  - `:project_traits` - client/framework traits used for system prompt guidance
  - `:backend_tool_modules` - backend tool modules available for execution
  - `:mcp_tool_defs` - client MCP tool definitions with timeout/policy metadata

  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:ok, :already_running}` - An execution is already running for this task
  - `{:error, :no_api_key}` - No API key available
  """
  def run(%Scope{} = scope, %TaskSchema{} = task, %{
        tools: tools,
        model: requested_model,
        turn_number: turn_number,
        interaction_rows: interaction_rows,
        project_traits: project_traits,
        backend_tool_modules: backend_tool_modules,
        mcp_tool_defs: mcp_tool_defs
      }) do
    max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)

    case Providers.prepare_llm_args(scope, requested_model, max_tokens: max_tokens) do
      {:ok, {model_spec, llm_opts}} ->
        agent = %RootAgent{
          task: task,
          scope: scope,
          turn_number: turn_number,
          messages: prompt_messages(interaction_rows, turn_number),
          tools: tools,
          backend_tool_modules: backend_tool_modules,
          mcp_tool_defs: mcp_tool_defs,
          system_prompt: system_prompt(task, project_traits),
          model: model_spec,
          llm_opts: llm_opts
        }

        case SwarmAi.run(FrontmanServer.AgentRuntime, agent) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, :already_running} ->
            {:ok, :already_running}

          error ->
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  def notify_tool_result(tool_call_id, result, is_error) do
    case Elixir.Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{caller_pid: caller}}] ->
        encoded = encode_result_for_swarm(result)
        send(caller, {:tool_result, tool_call_id, encoded, is_error})
        :notified

      [] ->
        :no_executor
    end
  end

  # --- Private ---
  defp prompt_messages(rows, turn_number)
       when is_list(rows) and is_integer(turn_number) and turn_number > 0 do
    Enum.flat_map(rows, fn
      %InteractionSchema{turn_number: row_turn} = row when row_turn < turn_number ->
        row
        |> row_to_messages()
        |> Enum.map(&decay_images/1)

      %InteractionSchema{turn_number: row_turn} = row when row_turn == turn_number ->
        row_to_messages(row)
    end)
  end

  defp row_to_messages(row) do
    row
    |> InteractionSchema.to_struct()
    |> List.wrap()
    |> Interaction.to_swarm_messages()
  end

  defp decay_images(%{content: content} = msg) when is_list(content) do
    %{msg | content: Enum.map(content, &decay_image_part/1)}
  end

  defp decay_images(msg), do: msg

  defp decay_image_part(%ContentPart{type: type}) when type in [:image, :image_url],
    do: ContentPart.text("[image: previously analyzed]")

  defp decay_image_part(part), do: part

  defp system_prompt(%TaskSchema{} = task, project_traits) do
    interactions = task.interactions

    Prompts.build(
      has_annotations:
        Enum.any?(interactions, &match?(%Interaction.UserMessage{annotations: [_ | _]}, &1)),
      project_traits: project_traits,
      framework: task.framework,
      project_rules: Enum.filter(interactions, &match?(%Interaction.DiscoveredProjectRule{}, &1)),
      project_structure: project_structure(interactions)
    )
  end

  defp project_structure(interactions) do
    case Enum.find(interactions, &match?(%Interaction.DiscoveredProjectStructure{}, &1)) do
      nil -> nil
      struct -> struct.summary
    end
  end

  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)

  @doc false
  def error_message(%Scope{}, :no_api_key),
    do: "No API key available for this request."

  def error_message(%Scope{}, :registration_timeout),
    do: "Agent failed to start. Please try again."

  def error_message(%Scope{}, reason),
    do: inspect(reason)
end
