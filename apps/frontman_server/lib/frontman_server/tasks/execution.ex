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
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.{LLMClient, Prompts, ToolExecutor}
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServer.Tools
  alias SwarmAi.{Loop, Message}
  alias SwarmAi.Message.ContentPart
  alias SwarmAi.Message.Tool

  @doc """
  Runs an agent execution for a task.

  Resolves provider auth, builds the root agent from the task,
  and submits the agent to SwarmAi.

  ## Params
  - `:model` - LLM model spec (nil uses provider default)
  - `:mcp_tools` - client MCP tool definitions for this turn
  - `:project_traits` - client/framework traits used for system prompt guidance

  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:error, {:start_failed, reason}}` - Execution worker failed to start
  - `{:error, :no_api_key}` - No API key available
  """
  def run(
        %Scope{} = scope,
        %TaskSchema{} = task,
        turn_number,
        %{
          model: requested_model,
          mcp_tools: mcp_tools,
          project_traits: project_traits
        }
      )
      when is_integer(turn_number) and turn_number > 0 and is_list(mcp_tools) and
             is_list(project_traits) do
    max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)

    case Providers.prepare_llm_args(scope, requested_model, max_tokens: max_tokens) do
      {:ok, {model_spec, llm_opts}} ->
        interaction_rows = interaction_rows(task.id, turn_number)
        backend_tool_modules = Tools.backend_tool_modules()
        tools = Tools.prepare_for_task(mcp_tools)

        messages = [
          Message.system(system_prompt(task, project_traits))
          | prompt_messages(interaction_rows, turn_number)
        ]

        llm = LLMClient.new(tools: tools, llm_opts: llm_opts, model: model_spec)
        execution_mode = Frameworks.tool_execution_mode(task.framework)

        execute_tools = fn tool_calls, task_supervisor ->
          ToolExecutor.execute(scope, %{
            task_id: task.id,
            turn_number: turn_number,
            tool_calls: tool_calls,
            task_supervisor: task_supervisor,
            backend_tool_modules: backend_tool_modules,
            mcp_tool_defs: mcp_tools,
            execution_mode: execution_mode
          })
        end

        dispatch_event = fn event ->
          Tasks.handle_swarm_event(scope, task.id, turn_number, event)
        end

        loop =
          Loop.new(%{
            task_id: task.id,
            turn_number: turn_number,
            messages: messages,
            llm: llm,
            execute_tools: execute_tools,
            dispatch_event: dispatch_event
          })

        SwarmAi.run(FrontmanServer.AgentRuntime, loop)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp interaction_rows(task_id, turn_number) do
    InteractionSchema.for_task(task_id)
    |> InteractionSchema.up_to_turn(turn_number)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  def notify_tool_result(%Interaction.ToolResult{
        tool_call_id: tool_call_id,
        result: %{"content" => [_ | _] = content},
        is_error: is_error
      }) do
    if Enum.all?(content, &is_map/1) do
      notify_tool_result(tool_call_id, content, is_error)
    else
      :no_executor
    end
  end

  def notify_tool_result(%Interaction.ToolResult{}), do: :no_executor

  defp notify_tool_result(tool_call_id, content, is_error) do
    case Elixir.Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{caller_pid: caller}}] ->
        content_parts =
          content
          |> Enum.map(&to_swarm_content_part/1)

        send(caller, {:tool_result, tool_call_id, content_parts, is_error})

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
    # FIXME(Danni) - why not get rid of swarm messages? lets it just work with reqllm messages
    |> Interaction.to_swarm_messages()
  end

  defp decay_images(%Tool{content: content, tool_call_id: tool_call_id} = msg)
       when is_list(content) do
    %{msg | content: Enum.map(content, &decay_image_part(&1, tool_call_id))}
  end

  defp decay_images(msg), do: msg

  defp decay_image_part(%ContentPart{type: type}, tool_call_id)
       when type in [:image, :image_url] do
    ContentPart.text("[image: omitted, tool_call_id: #{tool_call_id}]")
  end

  defp decay_image_part(part, _tool_call_id), do: part

  defp system_prompt(%TaskSchema{} = task, project_traits) do
    # QUESTION(Danni) - this is weird, in the caller-apps/frontman_server/lib/frontman_server/tasks/execution.ex:L47
    # we pass interaction_rows, but here we get task.interactions, weird
    interactions = task.interactions

    Prompts.build(
      # FIXME(Danni) - has_annotations will be true even if the last message doesnt have annotations
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

  defp to_swarm_content_part(%{"type" => "text", "text" => text}), do: ContentPart.text(text)

  defp to_swarm_content_part(%{"type" => "image", "data" => data, "mimeType" => mime_type}),
    do: ContentPart.image(Base.decode64!(data), mime_type)

  @doc false
  def error_message(%Scope{}, :no_api_key),
    do: "No API key available for this request."

  def error_message(%Scope{}, :registration_timeout),
    do: "Agent failed to start. Please try again."

  def error_message(%Scope{}, reason),
    do: inspect(reason)
end
