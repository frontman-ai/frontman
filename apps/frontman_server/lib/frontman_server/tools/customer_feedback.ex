# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.CustomerFeedback do
  @moduledoc "Server-side integration for the browser's customer feedback tool."

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks

  @tool_name "request_customer_feedback"

  def filter_tools(tools, %Scope{} = scope) when is_list(tools) do
    with true <- Enum.any?(tools, &(&1.name == @tool_name)),
         false <- CustomerFeedback.eligible?(scope) do
      Enum.reject(tools, &(&1.name == @tool_name))
    else
      false -> tools
      true -> tools
    end
  end

  def tool_request(%Scope{} = scope, task_id, turn, %{name: @tool_name} = call) do
    with {:ok, request} <- Tasks.get_tool_request(scope, task_id, turn, call) do
      CustomerFeedback.record_request(scope, request)
    end
  end

  def tool_request(_scope, _task_id, _turn, _call), do: {:ok, :not_feedback}

  def tool_result(_scope, _task_id, _turn, _call, %{"isError" => true} = result),
    do: {:ok, result}

  def tool_result(%Scope{} = scope, task_id, turn, %{name: @tool_name} = call, result) do
    with {:ok, request} <- Tasks.get_tool_request(scope, task_id, turn, call) do
      record_tool_answer(scope, request.id, result)
    end
  end

  def tool_result(_scope, _task_id, _turn, _call, result), do: {:ok, result}

  defp record_tool_answer(_scope, _id, %{
         "structuredContent" => %{"outcome" => "skipped"} = output
       })
       when map_size(output) == 1,
       do: {:ok, tool_reply(output)}

  defp record_tool_answer(scope, id, %{
         "structuredContent" => %{"outcome" => "answered", "score" => _score} = output
       }) do
    with true <- Map.drop(output, ["outcome", "score", "comment"]) == %{},
         {:ok, answer} <-
           CustomerFeedback.record_answer(scope, id, Map.take(output, ["score", "comment"])) do
      data =
        case answer.comment do
          nil -> %{"outcome" => "answered", "score" => answer.score}
          comment -> %{"outcome" => "answered", "score" => answer.score, "comment" => comment}
        end

      {:ok, tool_reply(data)}
    else
      false -> {:error, :invalid_customer_feedback}
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_tool_answer(_scope, _id, _result), do: {:error, :invalid_customer_feedback}

  defp tool_reply(output) do
    output
    |> Jason.encode!()
    |> MCP.tool_result_text()
    |> Map.put("structuredContent", output)
  end
end
