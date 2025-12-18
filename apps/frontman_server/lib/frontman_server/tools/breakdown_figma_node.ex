defmodule FrontmanServer.Tools.BreakdownFigmaNode do
  @moduledoc """
  Spawns a sub-agent to analyze a Figma node and break it down into components.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP
  alias FrontmanServer.Tasks.Interaction

  @system_prompt """
  You are a Figma design breakdown specialist. Your task is to analyze a Figma node
  and break it down into individual UI components that a developer should build.

  Think like a senior frontend developer planning their work:
  - Identify logical UI components (headers, cards, buttons, forms, etc.)
  - Consider reusability - similar elements should be the same component
  - Break down large sections into manageable pieces
  - Order by build dependencies (build foundational components first)

  ## Instructions

  1. **Analyze the structure** - Look at the node hierarchy to identify logical groupings
  2. **Identify components** - Find reusable UI patterns (buttons, cards, forms, etc.)
  3. **Consider volume** - Break down large sections into smaller, manageable pieces
  4. **Create the todo list** - List each component with:
     - A descriptive name (e.g., "Header Navigation", "Hero Section", "Feature Card")
     - The Figma node ID (from the skeleton, marked with #ID)
     - Estimated complexity (1-10)
     - Any dependencies on other components

  ## Output Format

  Provide a structured breakdown in this format:

  ```
  ## Component Breakdown

  ### 1. [Component Name]
  - **Node ID:** #X:XXX
  - **Complexity:** X/10
  - **Description:** Brief description of what this component does
  - **Dependencies:** List any components this depends on (or "None")

  ### 2. [Next Component]
  ...
  ```

  Order components by suggested build order (dependencies first, then complexity).

  IMPORTANT INSTRUCTIONS:
  - Analyze the provided node skeleton (DSL format) carefully
  - If an image is provided, use it to understand the visual design
  - Keep individual component complexity reasonable (respect maxComponentVolume)
  - Include the Figma node ID for each component so it can be fetched later
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the breakdown
  - Your response will be used to plan the implementation work
  """

  @impl true
  def name, do: "breakdown_figma_node"

  @impl true
  def description do
    """
    Analyze a Figma node and break it down into a list of components to build.

    Use this tool when you have a Figma design that needs to be implemented.
    The tool will analyze the node structure and image to identify individual
    components that should be built separately.

    The output is a todo list of components with their node IDs, descriptions,
    and suggested build order.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "nodeId" => %{
          "type" => "string",
          "description" => "The root Figma node ID to analyze (e.g., '0:1927' or '123:456')"
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
  def execute(args, %Context{task: task, agent_id: parent_agent_id}) do
    node_id = Map.get(args, "nodeId")
    max_volume = Map.get(args, "maxComponentVolume", 5)
    figma_context = Map.get(args, "context")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "BreakdownFigmaNode: Starting breakdown for node #{node_id} with #{length(mcp_tools)} MCP tools"
    )

    case extract_figma_data(task.interactions) do
      {:ok, figma_image, figma_skeleton} ->
        system_msg = ReqLLM.Context.system(@system_prompt, cache_control: %{type: "ephemeral"})

        user_msg =
          build_user_message(node_id, max_volume, figma_context, figma_image, figma_skeleton)

        case Agents.execute_sub_agent(task.id, [system_msg, user_msg],
               tools: mcp_tools,
               role: "figma_breakdown",
               parent_agent_id: parent_agent_id
             ) do
          {:ok, result} ->
            Logger.info("BreakdownFigmaNode: Completed breakdown for node #{node_id}")
            {:ok, %{"breakdown" => result, "nodeId" => node_id}}

          {:error, reason} ->
            Logger.error("BreakdownFigmaNode: Failed - #{inspect(reason)}")
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
    #{figma_skeleton || "No skeleton available"}
    ```

    ## Output Format

    Provide a structured component breakdown as specified in your instructions.
    """

    case figma_image do
      nil ->
        ReqLLM.Context.user(task_text)

      image_data when is_binary(image_data) ->
        case decode_image_data(image_data) do
          {:ok, binary_data, mime_type} ->
            %ReqLLM.Message{
              role: :user,
              content: [
                ReqLLM.Message.ContentPart.text(task_text),
                ReqLLM.Message.ContentPart.image(binary_data, mime_type)
              ]
            }

          :error ->
            Logger.warning("BreakdownFigmaNode: Failed to decode image, using text-only")
            ReqLLM.Context.user(task_text)
        end
    end
  end

  defp extract_figma_data(interactions) do
    content_blocks =
      interactions
      |> Enum.filter(&Interaction.user_message?/1)
      |> Enum.flat_map(fn %Interaction.UserMessage{content_blocks: blocks} -> blocks end)

    figma_image =
      content_blocks
      |> Enum.find(&figma_image?/1)
      |> extract_image_blob()

    figma_skeleton =
      content_blocks
      |> Enum.find(&figma_node?/1)
      |> extract_text_content()

    if figma_skeleton do
      {:ok, figma_image, figma_skeleton}
    else
      {:error, "No Figma node skeleton found in task interactions"}
    end
  end

  defp figma_image?(nil), do: false

  defp figma_image?(block) do
    get_in(block, ["resource", "_meta", "figma_image"]) == true
  end

  defp figma_node?(nil), do: false

  defp figma_node?(block) do
    case get_in(block, ["resource", "_meta", "figma_node"]) do
      true -> true
      _ -> figma_uri?(get_in(block, ["resource", "resource", "uri"]))
    end
  end

  defp figma_uri?("figma://node/" <> _), do: true
  defp figma_uri?(_), do: false

  defp extract_image_blob(nil), do: nil

  defp extract_image_blob(block) do
    case get_in(block, ["resource", "resource"]) do
      %{"blob" => base64, "mimeType" => mime} ->
        "data:#{mime || "image/png"};base64,#{base64}"

      _ ->
        nil
    end
  end

  defp extract_text_content(nil), do: nil
  defp extract_text_content(block), do: get_in(block, ["resource", "resource", "text"])

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
