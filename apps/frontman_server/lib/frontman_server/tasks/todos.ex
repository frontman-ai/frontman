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

  defmodule Todo do
    use TypedStruct
    @valid_statuses [:pending, :in_progress, :completed]

    @new_schema Zoi.object(%{
                  content: Zoi.string() |> Zoi.min(1),
                  active_form: Zoi.string() |> Zoi.min(1),
                  status: Zoi.string() |> Zoi.one_of(["pending", "in_progress", "completed"])
                })
    @extra_schema Zoi.object(%{
                    id: Zoi.string(),
                    created_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct(),
                    updated_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()
                  })
    @schema Zoi.extend(@new_schema, @extra_schema)

    typedstruct do
      field :id, String.t(), enforce: true
      field :content, String.t(), enforce: true
      field :active_form, String.t(), enforce: true
      field :status, atom(), enforce: true
      field :created_at, DateTime.t(), enforce: true
      field :updated_at, DateTime.t(), enforce: true
    end

    def schema do
      @schema
    end

    def valid_statuses do
      @valid_statuses
    end

    def make(content, active_form, status) do
      case Zoi.parse(@new_schema, %{content: content, active_form: active_form, status: status}) do
        {:ok, validated} ->
          now = DateTime.utc_now()
          status_atom = String.to_existing_atom(validated.status)

          todo = %__MODULE__{
            id: Ecto.UUID.generate(),
            content: validated.content,
            active_form: validated.active_form,
            status: status_atom,
            created_at: now,
            updated_at: now
          }

          {:ok, todo}

        {:error, errors} ->
          {:error, Zoi.prettify_errors(errors)}
      end
    end
  end

  alias Todos.Projection

  @doc """
  Lists all current todos by rebuilding state from interactions.
  
  Uses event projection instead of string matching.
  """
  @spec list_todos(list(Interaction.t())) :: %{String.t() => Todo.t()}
  def list_todos(interactions) do
    Projection.project(interactions)
  end

  @doc """
  Creates a new todo (in memory, returns for tool result).

  This doesn't persist - the tool callback will return this, which gets
  stored as a ToolResult interaction.
  """
  @spec create_todo(String.t(), String.t(), String.t()) :: {:ok, Todo.t()} | {:error, term()}
  def create_todo(content, active_form, status \\ "pending") do
    Todo.make(content, active_form, status)
  end

  @doc """
  Updates a todo's status by first rebuilding state, then updating.

  Caller must provide interactions list. Returns the updated todo for the tool result.
  """
  @spec update_todo_status(list(Interaction.t()), String.t(), String.t()) ::
          {:ok, Todo.t()} | {:error, term()}
  def update_todo_status(interactions, todo_id, status) do
    schema = Zoi.string() |> Zoi.one_of(["pending", "in_progress", "completed"])

    case Zoi.parse(schema, status) do
      {:ok, validated_status} ->
        state = list_todos(interactions)
        status_atom = String.to_existing_atom(validated_status)

        case Map.get(state, todo_id) do
          nil ->
            {:error, :not_found}

          %Todo{} = todo ->
            updated_todo = %{todo | status: status_atom, updated_at: DateTime.utc_now()}
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
    state = list_todos(interactions)

    if Map.has_key?(state, todo_id) do
      :ok
    else
      {:error, :not_found}
    end
  end
end
