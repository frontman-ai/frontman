# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.History do
  @moduledoc "Projects ordered task interactions into shared row and turn context."

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  @task_scoped_types InteractionSchema.task_scoped_types()
  @starter_types [:turn_started, :agent_retry]
  @terminal_types [:agent_completed, :agent_error, :agent_paused]
  @run_types [:agent_response, :tool_call, :tool_result]

  @enforce_keys ~w(rows ordered_rows users_by_id turns_by_number user_owners response_counts)a
  defstruct @enforce_keys

  @type row_context :: %{
          row: InteractionSchema.t(),
          turn_row: InteractionSchema.t() | nil,
          agent_id: String.t() | nil,
          response_ordinal: non_neg_integer() | nil
        }

  @type t :: %__MODULE__{
          rows: [InteractionSchema.t()],
          ordered_rows: [row_context()],
          users_by_id: %{String.t() => InteractionSchema.t()},
          turns_by_number: %{pos_integer() => InteractionSchema.t()},
          user_owners: %{String.t() => %{agent_id: String.t() | nil, turn_number: pos_integer()}},
          response_counts: %{pos_integer() => non_neg_integer()}
        }

  @spec new([InteractionSchema.t()]) :: {:ok, t()} | {:error, term()}
  def new(rows) when is_list(rows) do
    history = %__MODULE__{
      rows: rows,
      ordered_rows: [],
      users_by_id: %{},
      turns_by_number: %{},
      user_owners: %{},
      response_counts: %{}
    }

    rows
    |> Enum.reduce_while({:ok, history}, &index_row/2)
    |> validate_user_links()
    |> project_ordered_rows()
  end

  @spec interactions(t()) :: [struct()]
  def interactions(%__MODULE__{rows: rows}), do: Enum.map(rows, & &1.data)

  @spec ordered_rows(t()) :: [row_context()]
  def ordered_rows(%__MODULE__{ordered_rows: rows}), do: rows

  @spec attributed_rows(t()) :: {:ok, [row_context()]} | {:error, term()}
  def attributed_rows(%__MODULE__{ordered_rows: rows}) do
    case Enum.find(rows, &match?(%{row: %{type: :user_message}, agent_id: nil}, &1)) do
      nil -> {:ok, rows}
      %{row: row} -> {:error, {:unknown_user_agent, row.id}}
    end
  end

  @spec agent_ids(t()) :: [String.t()]
  def agent_ids(%__MODULE__{ordered_rows: rows}) do
    rows
    |> Enum.map(& &1.agent_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @spec user_row(t(), String.t()) :: InteractionSchema.t()
  def user_row(%__MODULE__{users_by_id: users}, id), do: Map.fetch!(users, id)

  @spec turns(t()) :: [InteractionSchema.t()]
  def turns(%__MODULE__{rows: rows}), do: Enum.filter(rows, &(&1.type == :turn_started))

  @spec turn(t(), pos_integer()) :: {:ok, InteractionSchema.t()} | {:error, :missing_turn}
  def turn(%__MODULE__{turns_by_number: turns}, turn_number) do
    case Map.fetch(turns, turn_number) do
      {:ok, row} -> {:ok, row}
      :error -> {:error, :missing_turn}
    end
  end

  @spec turn_agent_id(t(), pos_integer()) :: {:ok, String.t()} | {:error, :missing_turn}
  def turn_agent_id(%__MODULE__{} = history, turn_number) do
    with {:ok, %InteractionSchema{data: %Interaction.TurnStarted{agent_id: agent_id}}} <-
           turn(history, turn_number) do
      {:ok, agent_id}
    end
  end

  @spec pending_accepted_messages(t()) :: [InteractionSchema.t()]
  def pending_accepted_messages(%__MODULE__{} = history) do
    Enum.filter(history.rows, fn
      %InteractionSchema{type: :user_message, id: id} ->
        not Map.has_key?(history.user_owners, id)

      _row ->
        false
    end)
  end

  @spec active_run_turn_number(t()) :: {:ok, pos_integer() | nil} | {:error, term()}
  def active_run_turn_number(%__MODULE__{rows: rows}) do
    rows
    |> Enum.reduce_while(nil, &project_active_run/2)
    |> case do
      {:error, reason} -> {:error, reason}
      turn_number -> {:ok, turn_number}
    end
  end

  @spec next_turn_number(t()) :: pos_integer()
  def next_turn_number(%__MODULE__{turns_by_number: turns}) do
    turns |> Map.keys() |> Enum.max(fn -> 0 end) |> Kernel.+(1)
  end

  @spec latest_turn_number(t()) :: non_neg_integer()
  def latest_turn_number(%__MODULE__{} = history), do: next_turn_number(history) - 1

  @spec turn_model(t(), pos_integer()) :: {:ok, String.t()} | {:error, :missing_model}
  def turn_model(%__MODULE__{} = history, turn_number) do
    with {:ok, %InteractionSchema{data: %Interaction.TurnStarted{user_message_ids: ids}}} <-
           turn(history, turn_number),
         %InteractionSchema{data: %Interaction.UserMessage{model: model}} <-
           ids |> Enum.map(&user_row(history, &1)) |> List.last(),
         true <- is_binary(model) and model != "" do
      {:ok, model}
    else
      _missing -> {:error, :missing_model}
    end
  end

  @spec response_context(t(), pos_integer(), String.t()) :: map()
  def response_context(%__MODULE__{} = history, turn_number, agent_id)
      when is_binary(agent_id) and agent_id != "" do
    {:ok, %InteractionSchema{id: id}} = turn(history, turn_number)

    %{
      turn_started_id: id,
      agent_id: agent_id,
      ordinal_offset: Map.get(history.response_counts, turn_number, 0)
    }
  end

  @spec turn_context(t(), non_neg_integer() | nil) :: map() | nil
  def turn_context(_history, turn_number) when turn_number in [nil, 0], do: nil

  def turn_context(%__MODULE__{} = history, turn_number) do
    {:ok, turn_row} = turn(history, turn_number)

    %{
      agent_id: turn_row.data.agent_id,
      turn_number: turn_number,
      turn_started_id: turn_row.id
    }
  end

  defp index_row(%InteractionSchema{type: :user_message, id: id} = row, {:ok, history}) do
    case Map.has_key?(history.users_by_id, id) do
      true -> {:halt, {:error, {:duplicate_user_row, id}}}
      false -> {:cont, {:ok, %{history | users_by_id: Map.put(history.users_by_id, id, row)}}}
    end
  end

  defp index_row(
         %InteractionSchema{
           type: :turn_started,
           turn_number: turn_number,
           data: %Interaction.TurnStarted{} = turn
         } = row,
         {:ok, history}
       )
       when is_integer(turn_number) and turn_number > 0 do
    with false <- Map.has_key?(history.turns_by_number, turn_number),
         {:ok, owners} <- assign_users(history.user_owners, turn, turn_number) do
      updated = %{
        history
        | turns_by_number: Map.put(history.turns_by_number, turn_number, row),
          user_owners: owners
      }

      {:cont, {:ok, updated}}
    else
      true -> {:halt, {:error, {:duplicate_turn, turn_number}}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp index_row(
         %InteractionSchema{type: :turn_started, turn_number: turn_number},
         {:ok, _history}
       ),
       do: {:halt, {:error, {:invalid_turn_number, turn_number}}}

  defp index_row(%InteractionSchema{}, {:ok, history}), do: {:cont, {:ok, history}}

  defp validate_user_links({:error, reason}), do: {:error, reason}

  defp validate_user_links({:ok, history}) do
    case Enum.find(Map.keys(history.user_owners), &(not Map.has_key?(history.users_by_id, &1))) do
      nil -> {:ok, history}
      id -> {:error, {:missing_user_row, id}}
    end
  end

  defp project_ordered_rows({:error, reason}), do: {:error, reason}

  defp project_ordered_rows({:ok, history}) do
    initial = %{rows: [], active_turn: nil, responses: %{}}

    history.rows
    |> Enum.reduce_while({:ok, initial}, fn row, {:ok, state} ->
      case row_context(history, row, state) do
        {:ok, context, state} -> {:cont, {:ok, %{state | rows: [context | state.rows]}}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, state} ->
        {:ok,
         %{
           history
           | ordered_rows: Enum.reverse(state.rows),
             response_counts: state.responses
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp row_context(
         history,
         %InteractionSchema{id: id, type: :user_message, data: message} = row,
         state
       ) do
    with {:ok, owner} <- user_owner(history, id, message),
         {:ok, turn_row} <- owner_turn(history, owner) do
      agent_id = owner && owner.agent_id
      {:ok, context(row, turn_row, agent_id, nil), state}
    end
  end

  defp row_context(
         _history,
         %InteractionSchema{type: :turn_started, turn_number: turn_number, data: turn} = row,
         %{active_turn: nil} = state
       ) do
    {:ok, context(row, row, turn.agent_id, nil), %{state | active_turn: turn_number}}
  end

  defp row_context(
         _history,
         %InteractionSchema{type: :turn_started, turn_number: turn_number},
         %{active_turn: active_turn}
       ),
       do: {:error, {:run_already_active, active_turn, turn_number}}

  defp row_context(_history, %InteractionSchema{type: type} = row, state)
       when type in @task_scoped_types,
       do: {:ok, context(row, nil, nil, nil), state}

  defp row_context(
         history,
         %InteractionSchema{type: :agent_retry, turn_number: turn_number} = row,
         %{active_turn: nil} = state
       ) do
    with {:ok, context, state} <- turn_context(history, row, state) do
      {:ok, context, %{state | active_turn: turn_number}}
    end
  end

  defp row_context(
         _history,
         %InteractionSchema{type: :agent_retry, turn_number: turn_number},
         %{active_turn: active_turn}
       ),
       do: {:error, {:run_already_active, active_turn, turn_number}}

  defp row_context(
         history,
         %InteractionSchema{type: type, turn_number: turn_number} = row,
         %{active_turn: turn_number} = state
       )
       when type in @terminal_types do
    with {:ok, context, state} <- turn_context(history, row, state) do
      {:ok, context, %{state | active_turn: nil}}
    end
  end

  defp row_context(
         _history,
         %InteractionSchema{type: type, turn_number: turn_number},
         %{active_turn: active_turn}
       )
       when type in @terminal_types,
       do: {:error, {:inactive_run, type, turn_number, active_turn}}

  defp row_context(
         history,
         %InteractionSchema{type: type, turn_number: turn_number} = row,
         %{active_turn: turn_number} = state
       )
       when type in @run_types,
       do: turn_context(history, row, state)

  defp row_context(
         _history,
         %InteractionSchema{type: type, turn_number: turn_number},
         %{active_turn: active_turn}
       )
       when type in @run_types,
       do: {:error, {:inactive_run, type, turn_number, active_turn}}

  defp turn_context(
         history,
         %InteractionSchema{
           type: :agent_response,
           data: %Interaction.AgentResponse{content: content}
         } =
           row,
         state
       )
       when is_binary(content) or is_nil(content) do
    ordinal = Map.get(state.responses, row.turn_number, 0)
    responses = Map.put(state.responses, row.turn_number, ordinal + 1)
    turn_row = Map.fetch!(history.turns_by_number, row.turn_number)

    {:ok, context(row, turn_row, turn_row.data.agent_id, ordinal),
     %{state | responses: responses}}
  end

  defp turn_context(
         _history,
         %InteractionSchema{type: :agent_response, data: %Interaction.AgentResponse{} = response},
         _state
       ),
       do: {:error, {:invalid_agent_response_content, response.id}}

  defp turn_context(history, row, state) do
    turn_row = Map.fetch!(history.turns_by_number, row.turn_number)
    {:ok, context(row, turn_row, turn_row.data.agent_id, nil), state}
  end

  defp context(row, turn_row, agent_id, response_ordinal) do
    %{row: row, turn_row: turn_row, agent_id: agent_id, response_ordinal: response_ordinal}
  end

  defp user_owner(history, id, message) do
    case {message.agent_id, Map.get(history.user_owners, id)} do
      {nil, nil} -> {:ok, nil}
      {nil, owner} -> {:ok, owner}
      {agent_id, nil} -> {:ok, %{agent_id: agent_id, turn_number: nil}}
      {agent_id, %{agent_id: agent_id} = owner} -> {:ok, owner}
      {_agent_id, _owner} -> {:error, {:user_agent_mismatch, id}}
    end
  end

  defp owner_turn(_history, nil), do: {:ok, nil}
  defp owner_turn(_history, %{turn_number: nil}), do: {:ok, nil}
  defp owner_turn(history, %{turn_number: turn_number}), do: turn(history, turn_number)

  defp assign_users(owners, turn, turn_number) do
    owner = %{agent_id: turn.agent_id, turn_number: turn_number}

    Enum.reduce_while(turn.user_message_ids, {:ok, owners}, fn id, {:ok, assigned} ->
      case Map.fetch(assigned, id) do
        :error -> {:cont, {:ok, Map.put(assigned, id, owner)}}
        {:ok, ^owner} -> {:cont, {:ok, assigned}}
        {:ok, _other} -> {:halt, {:error, {:user_message_in_multiple_turns, id}}}
      end
    end)
  end

  defp project_active_run(%InteractionSchema{type: type, turn_number: nil}, active)
       when type in @task_scoped_types or type == :user_message,
       do: {:cont, active}

  defp project_active_run(%InteractionSchema{type: type, turn_number: nil}, _active),
    do: {:halt, {:error, {:missing_turn_number, type}}}

  defp project_active_run(%InteractionSchema{type: type, turn_number: turn_number}, _active)
       when type in @starter_types and is_integer(turn_number) and turn_number > 0,
       do: {:cont, turn_number}

  defp project_active_run(%InteractionSchema{type: type, turn_number: turn_number}, turn_number)
       when type in @terminal_types,
       do: {:cont, nil}

  defp project_active_run(%InteractionSchema{type: type}, active)
       when type in @terminal_types or type in @run_types,
       do: {:cont, active}

  defp project_active_run(%InteractionSchema{type: type}, _active),
    do: {:halt, {:error, {:unknown_interaction_type, type}}}
end
