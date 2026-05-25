# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution do
  @moduledoc """
  Orchestrates agent execution for tasks.

  This module handles the mechanics of running an LLM agent loop:
  - Building agent configuration from task data
  - Submitting runs to SwarmAi.Runtime
  - Translating agent events to persistence calls and PubSub broadcasts
  - Routing tool result notifications to waiting executors

  ## Telemetry

  All agent telemetry is emitted by Swarm. This module passes `task_id` via
  metadata, which flows through all Swarm telemetry events.
  """

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.{Framework, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.{Interaction, Task}
  alias FrontmanServer.Tools

  @doc """
  Cancels a running execution for the given task.

  Returns `:ok` if the execution was cancelled, `{:error, :not_running}` if none is running.
  """
  @spec cancel(Accounts.scope(), String.t()) :: :ok | {:error, :not_running}
  def cancel(%Scope{}, task_id) do
    SwarmAi.Runtime.cancel(FrontmanServer.AgentRuntime, task_id)
  end

  @doc """
  Returns true if an execution is currently running for the given task.
  """
  @spec running?(Accounts.scope(), String.t()) :: boolean()
  def running?(%Scope{}, task_id) do
    SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
  end

  @doc """
  Runs an agent execution for a task.

  Resolves the API key, builds the agent configuration from the task,
  and submits the run to SwarmAi.Runtime.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:model` - LLM model spec (defaults to provider default)
  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:ok, :already_running}` - An execution is already running for this task
  - `{:error, :no_api_key}` - No API key available
  - `{:error, :usage_limit_exceeded}` - Server key quota exhausted
  """
  @spec run(Accounts.scope(), Task.t(), keyword()) ::
          {:ok, pid() | :already_running} | {:error, :no_api_key | :usage_limit_exceeded | term()}
  def run(%Scope{} = scope, %Task{} = task, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    model = opts |> Keyword.get(:model) |> Providers.resolve_model_string()

    # Resolve API key at the domain layer (earliest point)
    case Providers.prepare_api_key(scope, model) do
      {:ok, api_key_info} ->
        max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)
        {model_spec, llm_opts} = Providers.to_llm_args(api_key_info, max_tokens: max_tokens)

        llm_opts =
          llm_opts
          |> maybe_enable_prompt_cache(api_key_info.provider)

        task_id = task.task_id
        agent = build_agent(task, tools, model_spec, llm_opts, task.framework)

        messages =
          task.interactions
          |> Interaction.to_swarm_messages()

        mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])

        backend_tool_modules =
          Keyword.get(opts, :backend_tool_modules, Tools.backend_tool_modules())

        tool_executor =
          ToolExecutor.make_executor(scope, task_id,
            backend_tool_modules: backend_tool_modules,
            mcp_tool_defs: mcp_tool_defs
          )

        # Emit task start telemetry BEFORE Runtime.run to avoid race with task_stop
        # in event handlers — the agent may complete before this line returns.
        TelemetryEvents.task_start(task_id)

        case SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
               metadata: %{
                 task_id: task_id,
                 resolved_key: api_key_info,
                 scope: scope,
                 interaction_id: Keyword.get(opts, :interaction_id)
               },
               tool_executor: tool_executor,
               tool_execution_mode: tool_execution_mode(task.framework)
             ) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, :already_running} ->
            TelemetryEvents.task_stop(task_id)
            {:ok, :already_running}

          error ->
            TelemetryEvents.task_stop(task_id)
            error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Called by the Tasks facade after persisting the tool result interaction.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  @spec notify_tool_result(Accounts.scope(), String.t(), term(), boolean()) ::
          :notified | :no_executor
  def notify_tool_result(%Scope{}, tool_call_id, result, is_error) do
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

  defp maybe_enable_prompt_cache(opts, "anthropic"),
    do: Keyword.put(opts, :anthropic_prompt_cache, true)

  defp maybe_enable_prompt_cache(opts, _provider), do: opts

  defp tool_execution_mode(%Framework{id: :wordpress}), do: :serial
  defp tool_execution_mode(_framework), do: :parallel

  defp build_agent(%Task{} = task, tools, model_spec, llm_opts, %Framework{} = fw) do
    has_typescript_react = Framework.has_typescript_react?(fw)

    # Derive prompt data from task interactions
    project_rules =
      task.interactions
      |> Enum.filter(&match?(%Interaction.DiscoveredProjectRule{}, &1))

    project_structure =
      task.interactions
      |> Enum.find(&match?(%Interaction.DiscoveredProjectStructure{}, &1))
      |> case do
        nil -> nil
        struct -> struct.summary
      end

    RootAgent.new(
      tools: tools,
      has_annotations: Interaction.has_annotations?(task.interactions),
      has_typescript_react: has_typescript_react,
      framework: fw,
      model: model_spec,
      llm_opts: llm_opts,
      project_rules: project_rules,
      project_structure: project_structure
    )
  end

  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)

  @doc false
  def error_message(%Scope{}, :usage_limit_exceeded),
    do: "Free requests exhausted. Add your API key in Settings to continue."

  def error_message(%Scope{}, :no_api_key),
    do: "No API key available for this request."

  def error_message(%Scope{}, :registration_timeout),
    do: "Agent failed to start. Please try again."

  def error_message(%Scope{}, reason),
    do: inspect(reason)
end
