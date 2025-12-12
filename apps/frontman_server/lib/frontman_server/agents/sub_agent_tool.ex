defmodule FrontmanServer.Agents.SubAgentTool do
  @moduledoc """
  Defines the spawn_sub_agent tool available to parent agents.

  This tool is handled internally by AgentServer - it spawns a sub-agent
  process rather than routing to MCP or executing as a backend tool.
  """

  alias FrontmanServer.Agents

  @tool_name "spawn_sub_agent"

  @doc "Returns the tool name constant"
  def tool_name, do: @tool_name

  @doc "Returns the tool definition for LLM"
  def tool_definition do
    type_descriptions =
      Agents.roles()
      |> Enum.map(fn role ->
        {:ok, config} = Agents.get_role(role)
        "- #{role}: #{config.description}"
      end)
      |> Enum.join("\n")

    %{
      name: @tool_name,
      description: """
      Spawn a specialized sub-agent to handle a specific task.
      The sub-agent will work autonomously and return a result.

      Available agent types:
      #{type_descriptions}

      Use this when a task requires specialized focus or parallel processing.
      You can spawn multiple sub-agents at once for independent tasks.
      """,
      parameters: %{
        type: "object",
        properties: %{
          agent: %{
            type: "string",
            enum: Enum.map(Agents.roles(), &Atom.to_string/1),
            description: "The type of agent to spawn"
          },
          message: %{
            type: "string",
            description: "A clear, specific description of what the agent should do"
          }
        },
        required: ["agent", "message"]
      }
    }
  end

  @doc "Parses tool call arguments and validates them"
  @spec parse_arguments(map()) ::
          {:ok, %{role: Agents.role(), message: String.t()}} | {:error, String.t()}
  def parse_arguments(%{"agent" => agent_str, "message" => message}) when is_binary(message) do
    case Agents.parse_role(agent_str) do
      {:ok, role} ->
        if String.trim(message) == "" do
          {:error, "Message cannot be empty"}
        else
          {:ok, %{role: role, message: message}}
        end

      {:error, :not_found} ->
        valid = Agents.roles() |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")
        {:error, "Invalid agent type '#{agent_str}'. Valid types: #{valid}"}
    end
  end

  def parse_arguments(%{"agent" => _}), do: {:error, "Missing or invalid 'message' parameter"}
  def parse_arguments(%{"message" => _}), do: {:error, "Missing 'agent' parameter"}
  def parse_arguments(_), do: {:error, "Missing required parameters 'agent' and 'message'"}
end
