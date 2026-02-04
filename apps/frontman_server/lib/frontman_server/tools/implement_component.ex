defmodule FrontmanServer.Tools.ImplementComponent do
  @moduledoc """
  Spawns a sub-agent to implement a single UI component from design specifications.

  The sub-agent focuses on implementation and test page creation:
  1. Analyze the design and take notes on key details
  2. Implement the component based on the design data
  3. Create a test page to render the component

  After this tool completes, use `fix_files_errors` to fix any errors.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents.SpecializedAgent
  alias FrontmanServer.Tools.Backend.Context
  alias Swarm.Message

  @impl true
  def name, do: "implement_component"

  @impl true
  def description do
    """
    Implement a single UI component based on design data.

    The tool will spawn a sub-agent that analyzes the design,
    implements the component, and creates a test page to render it.

    After this tool completes, use `fix_files_errors` to fix any errors.
    This tool returns the file paths created and implementation summary.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" =>
            "A descriptive name for the component (e.g., 'Header Navigation', 'Feature Card')"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "The node ID for this component"
        },
        "description" => %{
          "type" => "string",
          "description" => "Brief description of what the component does and its purpose"
        },
        "complexity" => %{
          "type" => "integer",
          "description" => "(Optional) Estimated complexity (1-10) from the breakdown analysis"
        },
        "dependencies" => %{
          "type" => "string",
          "description" =>
            "(Optional) Components this depends on, or 'None'. Used to understand build order."
        },
        "targetPath" => %{
          "type" => "string",
          "description" =>
            "(Optional) Target file path where the component should be created (e.g., 'components/Header.tsx')"
        },
        "additionalContext" => %{
          "type" => "string",
          "description" =>
            "(Optional) Any additional context or requirements for this specific component"
        }
      },
      "required" => ["componentName", "nodeId", "description"]
    }
  end

  @impl true
  def execute(args, %Context{} = context) do
    %{
      tool_executor: tool_executor,
      mcp_tools: mcp_tools,
      context_messages: context_messages,
      llm_opts: llm_opts
    } = context

    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    data_test_id = generate_data_test_id(component_name)

    Logger.info(
      "ImplementComponent: Starting implementation of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args, data_test_id)

    # Build message list: context files (conventions/research), then user message
    messages = context_messages ++ [user_msg]

    # Build ComponentImplementAgent - use executor from context
    agent =
      SpecializedAgent.new(:component_implement,
        tools: mcp_tools,
        model: llm_opts[:model],
        llm_opts: llm_opts
      )

    case Swarm.run_blocking(agent, messages, tool_executor) do
      {:ok, result, _loop_id} ->
        Logger.info("ImplementComponent: Completed #{component_name}")

        {:ok,
         %{
           "implementation" => result,
           "componentName" => component_name,
           "nodeId" => node_id,
           "dataTestId" => data_test_id
         }}

      {:error, reason, _loop_id} ->
        Logger.error("ImplementComponent: Failed - #{inspect(reason)}")
        {:error, "Implementation failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args, data_test_id) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    description = Map.get(args, "description")
    complexity = Map.get(args, "complexity")
    dependencies = Map.get(args, "dependencies", "None")
    target_path = Map.get(args, "targetPath")
    additional_context = Map.get(args, "additionalContext")

    complexity_str = if complexity, do: "#{complexity}/10", else: "Unknown"
    target_path_str = if target_path, do: "\n- **Target Path:** #{target_path}", else: ""

    additional_context_str =
      if additional_context do
        "\n\n## Additional Context\n\n#{additional_context}"
      else
        ""
      end

    task_text = """
    ## Implement Component

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Description:** #{description}
    - **Complexity:** #{complexity_str}
    - **Dependencies:** #{dependencies}#{target_path_str}
    - **Data Test ID:** `#{data_test_id}` (MUST be added to the top-level/root element as `data-test-id="#{data_test_id}"`)

    ## Implementation
    #{additional_context_str}

    Implement the component following your instructions.
    Remember: The top-level element MUST have `data-test-id="#{data_test_id}"`.
    """

    Message.user(task_text)
  end

  defp generate_data_test_id(component_name) do
    component_name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
