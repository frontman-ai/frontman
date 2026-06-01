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
  - Translating agent events to persistence calls and PubSub broadcasts
  - Routing tool result notifications to waiting executors

  ## Telemetry

  All agent telemetry is emitted by Swarm and correlated by agent id.
  """

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.{Prompts, RootAgent}
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema, Task}
  alias FrontmanServer.Tools
  alias SwarmAi.Message.ContentPart

  @doc """
  Runs an agent execution for a task.

  Resolves the API key, builds the root agent from the task,
  and submits the agent to SwarmAi.

  ## Options
  - `:model` - LLM model spec (defaults to provider default)
  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:ok, :already_running}` - An execution is already running for this task
  - `{:error, :no_api_key}` - No API key available
  """
  @spec run(Accounts.scope(), Task.t(), [SwarmAi.Tool.t()], keyword()) ::
          {:ok, pid() | :already_running} | {:error, :no_api_key | term()}
  def run(%Scope{} = scope, %Task{} = task, tools, opts \\ []) when is_list(tools) do
    model = opts |> Keyword.get(:model) |> Providers.resolve_model_string()
    turn_number = Keyword.fetch!(opts, :turn_number)
    interaction_rows = Keyword.fetch!(opts, :interaction_rows)

    # Resolve API key at the domain layer (earliest point)
    case Providers.prepare_api_key(scope, model) do
      {:ok, api_key_info} ->
        max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)
        {model_spec, llm_opts} = Providers.to_llm_args(api_key_info, max_tokens: max_tokens)

        llm_opts =
          llm_opts
          |> maybe_enable_prompt_cache(api_key_info.provider)

        project_traits = Keyword.get(opts, :project_traits, [])

        agent = %RootAgent{
          task: task,
          scope: scope,
          turn_number: turn_number,
          messages: prompt_messages(interaction_rows, turn_number),
          tools: tools,
          backend_tool_modules:
            Keyword.get(opts, :backend_tool_modules, Tools.backend_tool_modules()),
          mcp_tool_defs: Keyword.get(opts, :mcp_tool_defs, []),
          system_prompt: system_prompt(task, project_traits),
          model: model_spec,
          llm_opts: llm_opts
        }

        # Emit task start telemetry BEFORE SwarmAi.run to avoid race with task_stop
        # in event handlers — the agent may complete before this line returns.
        TelemetryEvents.task_start(task.task_id)

        case SwarmAi.run(FrontmanServer.AgentRuntime, agent) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, :already_running} ->
            TelemetryEvents.task_stop(task.task_id)
            {:ok, :already_running}

          error ->
            TelemetryEvents.task_stop(task.task_id)
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
  @spec notify_tool_result(String.t(), term(), boolean()) ::
          :notified | :no_executor
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

  @doc false
  @spec prompt_messages([InteractionSchema.t()], pos_integer()) :: [SwarmAi.Message.t()]
  def prompt_messages(rows, turn_number)
      when is_list(rows) and is_integer(turn_number) and turn_number > 0 do
    {reversed_messages, old_message_count} =
      Enum.reduce(rows, {[], 0}, fn row, {acc, count} ->
        {messages, old?} = row_prompt_messages(row, turn_number)
        count = if old?, do: count + length(messages), else: count
        {Enum.reverse(messages, acc), count}
      end)

    messages = Enum.reverse(reversed_messages)
    {old_messages, current_messages} = Enum.split(messages, old_message_count)
    Enum.map(old_messages, &decay_images/1) ++ current_messages
  end

  # --- Private ---

  defp row_prompt_messages(%InteractionSchema{turn_number: nil, type: type}, _turn_number)
       when type in ["discovered_project_rule", "discovered_project_structure"],
       do: {[], false}

  defp row_prompt_messages(%InteractionSchema{turn_number: nil, type: type}, _turn_number),
    do: raise("Missing turn_number for prompt interaction type: #{type}")

  defp row_prompt_messages(%InteractionSchema{turn_number: row_turn} = row, turn_number)
       when is_integer(row_turn) and row_turn > 0 and row_turn < turn_number,
       do: {row_to_messages(row), true}

  defp row_prompt_messages(%InteractionSchema{turn_number: row_turn} = row, turn_number)
       when is_integer(row_turn) and row_turn == turn_number,
       do: {row_to_messages(row), false}

  defp row_prompt_messages(%InteractionSchema{turn_number: row_turn}, turn_number),
    do: raise("Prompt row turn_number #{inspect(row_turn)} is invalid for turn #{turn_number}")

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

  defp system_prompt(%Task{} = task, project_traits) do
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

  defp maybe_enable_prompt_cache(opts, "anthropic"),
    do: Keyword.put(opts, :anthropic_prompt_cache, true)

  defp maybe_enable_prompt_cache(opts, _provider), do: opts

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
