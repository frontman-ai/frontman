# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.ToolCallExecutionClaim do
  @moduledoc """
  Durable execution authority stored inside a tool-call interaction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @dispatch_states [:claimed, :started]
  @resolution_states [:unresolved, :completed, :cancelled]
  @replay_policies [:verified_idempotent, :non_idempotent]
  @recovery_states [:none, :pending_resume, :resumed]

  @primary_key false
  embedded_schema do
    field :owner_connection_id, :string
    field :generation, :integer
    field :started_at, :utc_datetime_usec
    field :deadline_at, :utc_datetime_usec
    field :lease_expires_at, :utc_datetime_usec
    field :dispatch_state, Ecto.Enum, values: @dispatch_states
    field :resolution_state, Ecto.Enum, values: @resolution_states
    field :replay_policy, Ecto.Enum, values: @replay_policies
    field :recovery_state, Ecto.Enum, values: @recovery_states
  end

  @type dispatch_state :: :claimed | :started
  @type resolution_state :: :unresolved | :completed | :cancelled
  @type replay_policy :: :verified_idempotent | :non_idempotent
  @type recovery_state :: :none | :pending_resume | :resumed
  @type t :: %__MODULE__{
          owner_connection_id: String.t(),
          generation: pos_integer(),
          started_at: DateTime.t(),
          deadline_at: DateTime.t(),
          lease_expires_at: DateTime.t(),
          dispatch_state: dispatch_state(),
          resolution_state: resolution_state(),
          replay_policy: replay_policy(),
          recovery_state: recovery_state()
        }

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = claim, attrs) when is_map(attrs) do
    claim
    |> cast(attrs, [
      :owner_connection_id,
      :generation,
      :started_at,
      :deadline_at,
      :lease_expires_at,
      :dispatch_state,
      :resolution_state,
      :replay_policy,
      :recovery_state
    ])
    |> validate_required([
      :owner_connection_id,
      :generation,
      :started_at,
      :deadline_at,
      :lease_expires_at,
      :dispatch_state,
      :resolution_state,
      :replay_policy,
      :recovery_state
    ])
    |> validate_length(:owner_connection_id, min: 1)
    |> validate_number(:generation, greater_than: 0)
  end
end
