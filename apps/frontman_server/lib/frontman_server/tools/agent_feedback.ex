# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.AgentFeedback do
  @moduledoc """
  Lets agents send product feedback and feature requests to the Frontman team.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Workers.SendAgentFeedbackToDiscord
  alias ModelContextProtocol, as: MCP

  @outcomes ~w(completed stuck failed feature_request)

  @impl true
  def name, do: "agent_feedback"

  @impl true
  def description do
    """
    Send feedback to the Frontman team.

    Always write the feedback message in English, regardless of the session language.
    Continue responding to the user in their language.

    Use this before your final response when you completed a task and noticed
    missing Frontman capabilities, or when you are stuck/failing because a tool,
    context source, or workflow is missing or broken.
    """
  end

  @impl true
  def access, do: :write

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "outcome" => %{
          "type" => "string",
          "enum" => @outcomes,
          "description" => "Task outcome: completed, stuck, failed, or feature_request."
        },
        "message" => %{
          "type" => "string",
          "description" =>
            "What happened, what was missing, or what Frontman feature would help.",
          "maxLength" => 2000
        }
      },
      "required" => ["outcome", "message"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, %Context{task: task}) do
    with {:ok, outcome} <- validate_outcome(args["outcome"]),
         {:ok, message} <- validate_required_string(args["message"], "message") do
      %{
        task_id: task.id,
        framework: Atom.to_string(task.framework),
        task_title: task.short_desc,
        outcome: outcome,
        message: message
      }
      |> SendAgentFeedbackToDiscord.new()
      |> Oban.insert()
      |> case do
        {:ok, _job} -> MCP.tool_result_text("Feedback sent")
        {:error, reason} -> MCP.tool_result_error("Failed to send feedback: #{inspect(reason)}")
      end
    else
      {:error, reason} -> MCP.tool_result_error(reason)
    end
  end

  defp validate_outcome(outcome) when outcome in @outcomes, do: {:ok, outcome}

  defp validate_outcome(_outcome),
    do: {:error, "outcome must be one of: #{Enum.join(@outcomes, ", ")}"}

  defp validate_required_string(value, _field) when is_binary(value) do
    case byte_size(value) > 0 do
      true -> {:ok, value}
      false -> {:error, "message must be a non-empty string"}
    end
  end

  defp validate_required_string(_value, field),
    do: {:error, "#{field} must be a non-empty string"}
end
