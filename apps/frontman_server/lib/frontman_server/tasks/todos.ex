defmodule FrontmanServer.Tasks.Todos do
  @moduledoc """
  Event-sourced todo projection module.

  Rebuilds current todo state from ToolCall/ToolResult interactions.
  No state storage - todos exist only as events in the interaction log.

  Tool operations (add/update/remove) are recorded as ToolResult interactions,
  and the current state is reconstructed by replaying these events.

  This is a subcontext under Tasks - it accepts interactions as parameters
  and never calls back to the parent Tasks context.
  """

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.ToolResult

  @valid_statuses ~w(pending in_progress completed)
  @todo_tools ~w(todo_add todo_update todo_remove)

  # Define the Todo struct schema
  defmodule Todo do
    @schema Zoi.struct(__MODULE__, %{
      id: Zoi.string(),
      content: Zoi.string() |> Zoi.min(1),
      active_form: Zoi.string() |> Zoi.min(1),
      status: Zoi.string() |> Zoi.one_of(~w(pending in_progress completed)),
      created_at: Zoi.datetime(),
      updated_at: Zoi.datetime()
    })

    @type t :: unquote(Zoi.type_spec(@schema))
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    def schema, do: @schema

    @doc """
    Schema for deserializing a todo from JSON with ISO datetime strings.
    """
    def json_schema do
      Zoi.object(%{
        id: Zoi.string(),
        content: Zoi.string(),
        active_form: Zoi.string(),
        status: Zoi.string() |> Zoi.one_of(~w(pending in_progress completed)),
        created_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct(),
        updated_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()
      })
    end
  end

  @doc """
  Rebuilds current todo state from interaction history.

  Caller must provide interactions list - Todos subcontext doesn't access parent Tasks context.
  Returns a map of todo_id => todo for all currently active todos.
  """
  @spec rebuild_state(list(Interaction.t())) :: %{String.t() => Todo.t()}
  def rebuild_state(interactions) do
    interactions
    |> Enum.filter(&is_todo_tool_result?/1)
    |> Enum.reduce(%{}, &apply_todo_event/2)
  end

  @doc """
  Lists all current todos by rebuilding state from interactions.

  Caller must provide interactions list.
  """
  @spec list_todos(list(Interaction.t())) :: [Todo.t()]
  def list_todos(interactions) do
    interactions
    |> rebuild_state()
    |> Map.values()
    |> Enum.sort_by(& &1.created_at, DateTime)
  end

  @doc """
  Creates a new todo (in memory, returns for tool result).

  This doesn't persist - the tool callback will return this, which gets
  stored as a ToolResult interaction.
  """
  @spec create_todo(String.t(), String.t(), String.t()) :: {:ok, Todo.t()} | {:error, term()}
  def create_todo(content, active_form, status \\ "pending") do
    schema = Zoi.object(%{
      content: Zoi.string() |> Zoi.min(1),
      active_form: Zoi.string() |> Zoi.min(1),
      status: Zoi.string() |> Zoi.one_of(@valid_statuses)
    })

    case Zoi.parse(schema, %{content: content, active_form: active_form, status: status}) do
      {:ok, validated} ->
        now = DateTime.utc_now()
        todo = %Todo{
          id: Ecto.UUID.generate(),
          content: validated.content,
          active_form: validated.active_form,
          status: validated.status,
          created_at: now,
          updated_at: now
        }

        {:ok, todo}

      {:error, errors} ->
        {:error, Zoi.prettify_errors(errors)}
    end
  end

  @doc """
  Updates a todo's status by first rebuilding state, then updating.

  Caller must provide interactions list. Returns the updated todo for the tool result.
  """
  @spec update_todo_status(list(Interaction.t()), String.t(), String.t()) ::
    {:ok, Todo.t()} | {:error, term()}
  def update_todo_status(interactions, todo_id, status) do
    schema = Zoi.string() |> Zoi.one_of(@valid_statuses)

    case Zoi.parse(schema, status) do
      {:ok, validated_status} ->
        state = rebuild_state(interactions)

        case Map.get(state, todo_id) do
          nil ->
            {:error, :not_found}

          %Todo{} = todo ->
            updated_todo = %{todo |
              status: validated_status,
              updated_at: DateTime.utc_now()
            }
            {:ok, updated_todo}
        end

      {:error, errors} ->
        {:error, Zoi.prettify_errors(errors)}
    end
  end

  @doc """
  Validates a todo exists by rebuilding state.

  Caller must provide interactions list.
  """
  @spec validate_todo_exists(list(Interaction.t()), String.t()) :: :ok | {:error, :not_found}
  def validate_todo_exists(interactions, todo_id) do
    state = rebuild_state(interactions)

    if Map.has_key?(state, todo_id) do
      :ok
    else
      {:error, :not_found}
    end
  end

  # Private helpers

  defp is_todo_tool_result?(%ToolResult{tool_name: name}) when name in @todo_tools, do: true
  defp is_todo_tool_result?(_), do: false

  defp apply_todo_event(%ToolResult{tool_name: "todo_add", result: result}, state) do
    case Jason.decode(result, keys: :atoms) do
      {:ok, %{type: "todo_add", todo: todo_map}} ->
        case deserialize_todo(todo_map) do
          {:ok, todo} -> Map.put(state, todo.id, todo)
          {:error, _} -> state
        end

      _ ->
        state
    end
  end

  defp apply_todo_event(%ToolResult{tool_name: "todo_update", result: result}, state) do
    case Jason.decode(result, keys: :atoms) do
      {:ok, %{type: "todo_update", todo: todo_map}} ->
        case deserialize_todo(todo_map) do
          {:ok, todo} -> Map.put(state, todo.id, todo)
          {:error, _} -> state
        end

      _ ->
        state
    end
  end

  defp apply_todo_event(%ToolResult{tool_name: "todo_remove", result: result}, state) do
    case Jason.decode(result, keys: :atoms) do
      {:ok, %{type: "todo_remove", todo: %{id: id}}} ->
        Map.delete(state, id)

      _ ->
        state
    end
  end

  defp apply_todo_event(_, state), do: state

  defp deserialize_todo(todo_map) do
    case Zoi.parse(Todo.json_schema(), todo_map) do
      {:ok, validated} ->
        todo = struct(Todo, validated)
        {:ok, todo}
      {:error, _errors} ->
        {:error, :invalid_todo}
    end
  end
end
