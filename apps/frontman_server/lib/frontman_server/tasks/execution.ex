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
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.{LLMClient, ToolExecutor}
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
  - `:model` - LLM model spec
  - `:mcp_tools` - client MCP tool definitions for this turn

  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:error, {:start_failed, reason}}` - Execution worker failed to start
  - `{:error, :no_api_key}` - No API key available
  """
  def run(
        %Scope{} = scope,
        %TaskSchema{} = task,
        turn_number,
        system_prompt,
        interaction_rows,
        tool_policy,
        response_context,
        %{
          model: requested_model,
          mcp_tools: mcp_tools
        }
      )
      when is_integer(turn_number) and turn_number > 0 and is_binary(system_prompt) and
             is_list(interaction_rows) and is_list(mcp_tools) do
    max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)

    case Providers.prepare_llm_args(scope, requested_model, max_tokens: max_tokens) do
      {:ok, {model_spec, llm_opts}} ->
        backend_tool_modules = Tools.backend_tool_modules(tool_policy)
        mcp_tools = Tools.mcp_tools(mcp_tools, tool_policy)
        tools = Tools.to_swarm_tools(backend_tool_modules, mcp_tools)

        messages = [
          Message.system(system_prompt)
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

        dispatch_event = fn
          {:chunk, metadata, chunk} ->
            Tasks.handle_swarm_event(
              scope,
              task.id,
              turn_number,
              {:chunk, response_metadata(response_context, metadata), chunk}
            )

          {:response, metadata, response} ->
            Tasks.handle_swarm_event(
              scope,
              task.id,
              turn_number,
              {:response, response_metadata(response_context, metadata), response}
            )

          event ->
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

  defp response_metadata(response_context, metadata) do
    %{
      turn_started_id: response_context.turn_started_id,
      agent_id: response_context.agent_id,
      ordinal: response_context.ordinal_offset + metadata.ordinal,
      timestamp: metadata.timestamp
    }
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  def notify_tool_result(%Interaction.ToolResult{
        tool_call_id: tool_call_id,
        result: %{"content" => content},
        is_error: is_error
      })
      when is_list(content),
      do: notify_tool_result(tool_call_id, content, is_error)

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

  defp prompt_messages(rows, turn_number)
       when is_list(rows) and is_integer(turn_number) and turn_number > 0 do
    user_messages_by_row_id = user_messages_by_row_id(rows)

    rows
    |> Enum.filter(&(is_nil(&1.turn_number) or &1.turn_number <= turn_number))
    |> Enum.flat_map(fn row ->
      row
      |> row_to_messages(user_messages_by_row_id)
      |> decay_historical_images(row.turn_number, turn_number)
    end)
  end

  defp row_to_messages(
         %InteractionSchema{
           type: :turn_started,
           data: %Interaction.TurnStarted{user_message_ids: user_message_ids}
         },
         user_messages_by_row_id
       ) do
    user_message_ids
    |> Enum.map(&Map.fetch!(user_messages_by_row_id, &1))
    |> Interaction.to_swarm_messages()
  end

  defp row_to_messages(%InteractionSchema{turn_number: nil}, _user_messages_by_row_id),
    do: []

  defp row_to_messages(%InteractionSchema{} = row, _user_messages_by_row_id) do
    row_to_messages(row)
  end

  defp decay_historical_images(messages, row_turn, turn_number)
       when is_integer(row_turn) and row_turn < turn_number,
       do: Enum.map(messages, &decay_images/1)

  defp decay_historical_images(messages, _row_turn, _turn_number), do: messages

  defp user_messages_by_row_id(rows) do
    rows
    |> Enum.filter(&(&1.type == :user_message))
    |> Map.new(fn %InteractionSchema{id: id, data: %Interaction.UserMessage{} = message} ->
      {id, message}
    end)
  end

  defp row_to_messages(row) do
    row
    |> Map.fetch!(:data)
    |> List.wrap()
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

  defp to_swarm_content_part(%{"type" => "text", "text" => text}), do: ContentPart.text(text)

  defp to_swarm_content_part(%{"type" => "image", "data" => data, "mimeType" => mime_type}),
    do: ContentPart.image(Base.decode64!(data), mime_type)
end
