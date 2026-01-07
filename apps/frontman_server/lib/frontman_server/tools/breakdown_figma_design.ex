defmodule FrontmanServer.Tools.BreakdownFigmaDesign do
  @moduledoc """
  Spawns a sub-agent to analyze a Figma node and break it down into components.

  Uses FigmaBreakdownAgent with Swarm.run_blocking for execution.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents.{SpecializedAgent, ToolExecutor}
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP
  alias Swarm.Message

  @impl true
  def name, do: "breakdown_figma_design"

  @impl true
  def description do
    """
    Analyze a Figma node and break it down into a list of components to build.

    Use this tool when you have a Figma design that needs to be implemented.
    This tool uses the DSL (Domain Specific Language) representation of the Figma
    design - a compact, token-efficient format that shows the design structure.

    The tool will analyze the node structure (DSL) and image to identify individual
    components that should be built separately.

    The output is a todo list of components with their node IDs, descriptions,
    and suggested build order. Use these node IDs with `implement_component`,
    `fix_files_errors`, `visual_compare_component_to_figma`, and `fix_visual_issues`
    tools, which will fetch full node data via `get_figma_node`.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "nodeId" => %{
          "type" => "string",
          "description" => "The root Figma node ID to analyze"
        },
        "maxComponentVolume" => %{
          "type" => "integer",
          "description" =>
            "Maximum complexity volume (1-10) for any single component. Components exceeding this will be split further. Default: 5"
        },
        "context" => %{
          "type" => "string",
          "description" =>
            "Optional context about what's being built (e.g., 'landing page', 'dashboard'). Helps with component naming."
        }
      },
      "required" => ["nodeId"]
    }
  end

  @impl true
  def execute(args, %Context{task: task}) do
    node_id = Map.get(args, "nodeId")
    max_volume = Map.get(args, "maxComponentVolume", 5)
    figma_context = Map.get(args, "context")

    mcp_tools = MCP.to_swarm_tools(task.mcp_tools)

    Logger.info(
      "BreakdownFigmaDesign: Starting breakdown for node #{node_id} with #{length(mcp_tools)} MCP tools"
    )

    case extract_figma_data(task.interactions) do
      {:ok, figma_image, figma_skeleton} ->
        user_msg =
          build_user_message(node_id, max_volume, figma_context, figma_image, figma_skeleton)

        # Build FigmaBreakdownAgent and executor
        agent = SpecializedAgent.new(:figma_breakdown, tools: mcp_tools)
        tool_executor = ToolExecutor.make_executor(task.task_id)

        case Swarm.run_blocking(agent, [user_msg], tool_executor) do
          {:ok, result} ->
            Logger.info("BreakdownFigmaDesign: Completed breakdown for node #{node_id}")
            {:ok, %{"breakdown" => result, "nodeId" => node_id}}

          {:error, reason} ->
            Logger.error("BreakdownFigmaDesign: Failed - #{inspect(reason)}")
            {:error, "Breakdown failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_user_message(node_id, max_volume, context, figma_image, figma_skeleton) do
    context_str = if context, do: "\n- **Context:** #{context}", else: ""

    task_text = """
    Break down the following Figma node into components:

    - **Node ID:** #{node_id}
    - **Max Component Volume:** #{max_volume}#{context_str}

    ## Node Skeleton (DSL Format)

    ```
    #{figma_skeleton}
    ```

    ## Output Format

    Provide a structured component breakdown as specified in your instructions.
    """

    case figma_image do
      nil ->
        Message.user(task_text)

      image_data when is_binary(image_data) ->
        case decode_image_data(image_data) do
          {:ok, binary_data, mime_type} ->
            %Message{
              role: :user,
              content: [
                Message.ContentPart.text(task_text),
                Message.ContentPart.image(binary_data, mime_type)
              ]
            }

          :error ->
            Logger.warning("BreakdownFigmaDesign: Failed to decode image, using text-only")
            Message.user(task_text)
        end
    end
  end

  defp extract_figma_data(interactions) do
    # Get the selected Figma node from interactions
    case Interaction.get_selected_figma_node(interactions) do
      %Interaction.FigmaNode{node: node, image: image} when is_binary(node) ->
        # Convert image to data URL format expected by decode_image_data
        figma_image =
          if is_binary(image), do: "data:image/png;base64,#{image}", else: nil

        {:ok, figma_image, node}

      _ ->
        {:error, "No Figma node skeleton found in task interactions"}
    end
  end

  defp decode_image_data(data_url) do
    case Regex.run(~r/^data:([^;]+);base64,(.+)$/s, ensure_data_url(data_url)) do
      [_, mime_type, base64] ->
        case Base.decode64(base64) do
          {:ok, binary} -> {:ok, binary, mime_type}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp ensure_data_url("data:" <> _ = url), do: url
  defp ensure_data_url(base64_data), do: "data:image/png;base64,#{base64_data}"
end
