defmodule FrontmanServer.Agents.FigmaTools.BreakdownFigmaNode do
  @moduledoc """
  Backend tool that spawns a sub-agent to analyze a Figma node and break it
  down into a component todo list.

  This tool extracts the figma_node and figma_image from the task's interactions,
  then spawns a sub-agent with a specialized system prompt to analyze the design
  and produce a structured breakdown of components to build.
  """

  require Logger

  alias FrontmanServer.Agents.SubAgentExecutor
  alias FrontmanServer.Tasks
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

  @doc """
  Returns the tool definition for LLM.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(task_id) do
    ReqLLM.Tool.new!(
      name: "breakdown_figma_node",
      description: """
      Analyze a Figma node and break it down into a list of components to build.

      Use this tool when you have a Figma design that needs to be implemented.
      The tool will analyze the node structure and image to identify individual
      components that should be built separately.

      The output is a todo list of components with their node IDs, descriptions,
      and suggested build order.
      """,
      parameter_schema: %{
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
      },
      callback: fn args -> execute(task_id, args) end
    )
  end

  @doc """
  Executes the breakdown tool by spawning a sub-agent.
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def execute(task_id, args) do
    node_id = Map.get(args, "nodeId")
    max_volume = Map.get(args, "maxComponentVolume", 5)
    figma_context = Map.get(args, "context")

    # Get parent agent context from process dictionary (set by Tools.execute_tool)
    context = FrontmanServer.Tools.get_tool_context()
    parent_agent_id = Map.get(context, :agent_id)

    # Get MCP tools from task and convert to LLM format
    raw_mcp_tools = Tasks.get_mcp_tools(task_id)
    mcp_tools = mcp_tools_to_llm_format(raw_mcp_tools)

    Logger.info("BreakdownFigmaNode: Starting breakdown for node #{node_id} with #{length(mcp_tools)} MCP tools")

    # Extract figma content from task interactions
    case extract_figma_from_task(task_id) do
      {:ok, figma_image, figma_skeleton} ->
        # Build messages for sub-agent
        system_msg = ReqLLM.Context.system(@system_prompt, cache_control: %{type: "ephemeral"})
        user_msg = build_user_message(node_id, max_volume, figma_context, figma_image, figma_skeleton)

        # Execute sub-agent with MCP tools
        case SubAgentExecutor.execute(task_id, [system_msg, user_msg],
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

  defp extract_figma_from_task(task_id) do
    interactions = Tasks.get_interactions(task_id)

    content_blocks =
      interactions
      |> Enum.filter(&Interaction.user_message?/1)
      |> Enum.flat_map(fn %Interaction.UserMessage{content_blocks: blocks} -> blocks end)

    # Find figma_image content block
    figma_image =
      content_blocks
      |> Enum.find(&has_figma_meta?(&1, "figma_image"))
      |> extract_image_blob()

    # Find figma_node content block (skeleton/DSL)
    figma_skeleton =
      content_blocks
      |> Enum.find(&has_figma_meta?(&1, "figma_node"))
      |> extract_text_content()

    if figma_skeleton do
      {:ok, figma_image, figma_skeleton}
    else
      {:error, "No Figma node skeleton found in task interactions"}
    end
  end

  defp has_figma_meta?(nil, _), do: false

  defp has_figma_meta?(block, meta_key) do
    case Map.get(block, "resource") do
      %{"_meta" => meta} when is_map(meta) ->
        Map.get(meta, meta_key) == true

      # Fallback: check URI for figma_node
      %{"resource" => %{"uri" => uri}} when is_binary(uri) and meta_key == "figma_node" ->
        String.starts_with?(uri, "figma://node/")

      _ ->
        false
    end
  end

  defp extract_image_blob(nil), do: nil

  defp extract_image_blob(%{
         "resource" => %{"resource" => %{"blob" => base64, "mimeType" => mime}}
       }) do
    mime_type = mime || "image/png"
    "data:#{mime_type};base64,#{base64}"
  end

  defp extract_image_blob(_), do: nil

  defp extract_text_content(nil), do: nil
  defp extract_text_content(%{"resource" => %{"resource" => %{"text" => text}}}), do: text
  defp extract_text_content(_), do: nil

  defp decode_image_data(data_url) do
    # Handle both raw base64 and data URL format
    data_url = ensure_data_url(data_url)

    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end

  defp ensure_data_url("data:" <> _ = url), do: url
  defp ensure_data_url(base64_data), do: "data:image/png;base64,#{base64_data}"

  defp mcp_tools_to_llm_format(mcp_tools) do
    Enum.map(mcp_tools, fn tool ->
      ReqLLM.Tool.new!(
        name: tool["name"],
        description: tool["description"] || "",
        parameter_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
        callback: fn _args -> {:ok, "MCP tool - executed externally"} end
      )
    end)
  end
end
