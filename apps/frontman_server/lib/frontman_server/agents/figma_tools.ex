defmodule FrontmanServer.Agents.FigmaTools do
  @moduledoc """
  Figma tool definitions aggregator.

  Collects all Figma-related tools that spawn sub-agents to process
  Figma designs.
  """

  alias FrontmanServer.Agents.FigmaTools.{BreakdownFigmaNode, ImplementComponent}

  @doc """
  Returns all Figma tools for a given task.

  MCP tools are retrieved from the task when the tool executes.
  """
  @spec figma_tools(String.t()) :: [ReqLLM.Tool.t()]
  def figma_tools(task_id) do
    [
      BreakdownFigmaNode.tool(task_id),
      ImplementComponent.tool(task_id)
    ]
  end
end
