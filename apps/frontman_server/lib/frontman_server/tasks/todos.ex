defmodule FrontmanServer.Tasks.Todos do
  @moduledoc """
  Atomic todo projection module.

  Rebuilds current todo state from the last `todo_write` ToolResult interaction.
  No incremental mutations — the LLM sends the complete list every time,
  eliminating hallucinated IDs and state drift between turns.

  This is a subcontext under Tasks — it accepts interactions as parameters
  and never calls back to the parent Tasks context.
  """

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.TodoWrite

  defmodule Todo do
    @moduledoc false
    use TypedStruct
    @derive Jason.Encoder
    @valid_statuses [:pending, :in_progress, :completed]
    @valid_priorities [:high, :medium, :low]

    @new_schema Zoi.object(%{
                  content: Zoi.string() |> Zoi.min(1),
                  active_form: Zoi.string() |> Zoi.min(1),
                  status: Zoi.string() |> Zoi.one_of(["pending", "in_progress", "completed"]),
                  priority: Zoi.string() |> Zoi.one_of(["high", "medium", "low"])
                })
    @extra_schema Zoi.object(
                    %{
                      id: Zoi.string(),
                      created_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct(),
                      updated_at: Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()
                    },
                    coerce: true
                  )
    @schema Zoi.extend(@new_schema, @extra_schema)

    typedstruct do
      field(:id, String.t(), enforce: true)
      field(:content, String.t(), enforce: true)
      field(:active_form, String.t(), enforce: true)
      field(:status, atom(), enforce: true)
      field(:priority, atom(), enforce: true)
      field(:created_at, DateTime.t(), enforce: true)
      field(:updated_at, DateTime.t(), enforce: true)
    end

    def schema do
      @schema
    end

    def valid_statuses do
      @valid_statuses
    end

    def valid_priorities do
      @valid_priorities
    end

    def make(content, active_form, status, priority \\ "medium") do
      case Zoi.parse(@new_schema, %{
             content: content,
             active_form: active_form,
             status: status,
             priority: priority
           }) do
        {:ok, validated} ->
          now = DateTime.utc_now()

          todo = %__MODULE__{
            id: Ecto.UUID.generate(),
            content: validated.content,
            active_form: validated.active_form,
            status: String.to_existing_atom(validated.status),
            priority: String.to_existing_atom(validated.priority),
            created_at: now,
            updated_at: now
          }

          {:ok, todo}

        {:error, errors} ->
          {:error, Zoi.prettify_errors(errors)}
      end
    end
  end

  @doc """
  Lists all current todos from the last `todo_write` result.

  Finds the most recent successful `todo_write` ToolResult and parses its todos array.
  """
  @spec list_todos(list(Interaction.t())) :: %{String.t() => Todo.t()}
  def list_todos(interactions) do
    interactions
    |> Enum.filter(&todo_write_result?/1)
    |> List.last()
    |> case do
      nil -> %{}
      %Interaction.ToolResult{result: result} -> parse_write_result(result)
    end
  end

  defp todo_write_result?(%Interaction.ToolResult{tool_name: name, is_error: false}),
    do: name == TodoWrite.name()

  defp todo_write_result?(_), do: false

  defp parse_write_result(%{"todos" => todos}) when is_list(todos) do
    todos
    |> Enum.reduce(%{}, fn raw, acc ->
      case to_todo(raw) do
        {:ok, todo} -> Map.put(acc, todo.id, todo)
        :error -> acc
      end
    end)
  end

  defp parse_write_result(_), do: %{}

  defp to_todo(%Todo{} = todo), do: {:ok, todo}

  defp to_todo(map) when is_map(map) do
    case Zoi.parse(Todo.schema(), map) do
      {:ok, parsed} ->
        {:ok,
         %Todo{
           id: parsed.id,
           content: parsed.content,
           active_form: parsed.active_form,
           status: String.to_existing_atom(parsed.status),
           priority: String.to_existing_atom(parsed.priority),
           created_at: parsed.created_at,
           updated_at: parsed.updated_at
         }}

      {:error, _} ->
        :error
    end
  end

  defp to_todo(_), do: :error
end
