defmodule FrontmanServer.Tasks.InteractionSchema do
  @moduledoc """
  Ecto schema for persisted interactions.

  Interactions are stored with a type discriminator and JSONB data field.
  The `type` field indicates which interaction struct to deserialize to.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Tasks.TaskSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "interactions" do
    field(:type, :string)
    field(:data, :map)

    belongs_to(:task, TaskSchema)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @known_types ~w(
    user_message
    agent_response
    tool_call
    tool_result
    discovered_project_rule
    agent_spawned
    agent_completed
  )

  @type t :: %__MODULE__{}

  @doc """
  Changeset for creating an interaction from a domain struct.
  Extracts type from struct module name and data from struct fields.
  """
  @spec create_changeset(String.t(), struct()) :: Ecto.Changeset.t()
  def create_changeset(task_id, interaction) do
    type = interaction.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    attrs = %{
      task_id: task_id,
      type: type,
      data: Map.from_struct(interaction)
    }

    %__MODULE__{}
    |> cast(attrs, [:task_id, :type, :data])
    |> validate_required([:task_id, :type, :data])
    |> validate_inclusion(:type, @known_types)
    |> foreign_key_constraint(:task_id)
  end

  # Query helpers

  @spec for_task(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_task(query \\ __MODULE__, task_id) do
    from(i in query, where: i.task_id == ^task_id)
  end

  @spec ordered_by_inserted(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered_by_inserted(query \\ __MODULE__) do
    from(i in query, order_by: [asc: i.inserted_at])
  end

  # --- JSONB to Domain Struct Conversion ---

  alias FrontmanServer.Tasks.Interaction

  @doc """
  Converts a persisted InteractionSchema to its domain struct.
  """
  @spec to_struct(t()) :: Interaction.t()
  def to_struct(%__MODULE__{type: "user_message", data: data}) do
    %Interaction.UserMessage{
      id: data["id"],
      timestamp: parse_datetime(data["timestamp"]),
      messages: data["messages"] || [],
      selected_component: parse_selected_component(data["selected_component"]),
      selected_component_screenshot: data["selected_component_screenshot"],
      selected_figma_node: parse_figma_node(data["selected_figma_node"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_response", data: data}) do
    %Interaction.AgentResponse{
      id: data["id"],
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"]),
      metadata: data["metadata"]
    }
  end

  def to_struct(%__MODULE__{type: "tool_call", data: data}) do
    %Interaction.ToolCall{
      id: data["id"],
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      arguments: data["arguments"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "tool_result", data: data}) do
    %Interaction.ToolResult{
      id: data["id"],
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      result: data["result"],
      is_error: data["is_error"] || false,
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "discovered_project_rule", data: data}) do
    %Interaction.DiscoveredProjectRule{
      path: data["path"],
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_spawned", data: data}) do
    %Interaction.AgentSpawned{
      id: data["id"],
      config: data["config"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_completed", data: data}) do
    %Interaction.AgentCompleted{
      id: data["id"],
      result: data["result"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: type}) do
    raise "Unknown interaction type: #{type}"
  end

  @spec parse_datetime(DateTime.t() | String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  @spec parse_selected_component(map() | nil) :: map() | nil
  defp parse_selected_component(nil), do: nil

  defp parse_selected_component(data) when is_map(data) do
    %{
      file: data["file"],
      line: data["line"],
      column: data["column"],
      source_snippet: data["source_snippet"],
      source_type: data["source_type"],
      component_name: data["component_name"],
      component_props: data["component_props"],
      parent: parse_parent_chain(data["parent"])
    }
  end

  @spec parse_parent_chain(map() | nil) :: map() | nil
  defp parse_parent_chain(nil), do: nil

  defp parse_parent_chain(parent) when is_map(parent) do
    %{
      file: parent["file"],
      line: parent["line"],
      column: parent["column"],
      source_snippet: nil,
      source_type: nil,
      component_name: parent["component_name"],
      component_props: parent["component_props"],
      parent: parse_parent_chain(parent["parent"])
    }
  end

  defp parse_parent_chain(_), do: nil

  @spec parse_figma_node(map() | nil) :: Interaction.FigmaNode.t() | nil
  defp parse_figma_node(nil), do: nil

  defp parse_figma_node(data) when is_map(data) do
    %Interaction.FigmaNode{
      id: data["id"],
      node: data["node"],
      image: data["image"],
      is_dsl: data["is_dsl"] || true
    }
  end
end
