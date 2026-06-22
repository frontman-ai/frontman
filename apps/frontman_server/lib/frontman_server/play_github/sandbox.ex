# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Sandbox do
  @moduledoc """
  Persisted PlayGithub sandbox owned by a user.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User

  @statuses ~w(
    sandbox_creating sandbox_created sandbox_create_failed
    clone_starting clone_finished clone_failed install_starting install_finished
    install_failed dev_server_starting dev_server_started dev_server_failed
  )a
  @failure_statuses ~w(sandbox_create_failed clone_failed install_failed dev_server_failed)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "playgithub_sandboxes" do
    field(:github_url, :string)
    field(:daytona_sandbox_id, :string)
    field(:status, Ecto.Enum, values: @statuses)
    field(:status_started_at, :utc_datetime)
    field(:status_error, :string)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @doc """
  Changeset for creating a sandbox ownership row.

  `user_id` must be set on the struct before calling this changeset.
  """
  def create_changeset(%__MODULE__{} = sandbox, attrs) do
    sandbox
    |> cast(attrs, [:github_url])
    |> put_change(:status, :sandbox_creating)
    |> put_change(:status_started_at, DateTime.utc_now(:second))
    |> validate_required([:user_id, :github_url, :status])
    |> validate_length(:github_url, min: 1, max: 2_048)
    |> unique_constraint([:user_id, :github_url],
      name: :playgithub_sandboxes_user_id_github_url_index
    )
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for recording the Daytona sandbox id after external creation succeeds.
  """
  def attach_daytona_sandbox_changeset(%__MODULE__{} = sandbox, daytona_sandbox_id)
      when is_binary(daytona_sandbox_id) do
    sandbox
    |> change(
      daytona_sandbox_id: daytona_sandbox_id,
      status: :sandbox_created,
      status_started_at: DateTime.utc_now(:second),
      status_error: nil
    )
    |> validate_required([:daytona_sandbox_id])
    |> validate_length(:daytona_sandbox_id, min: 1, max: 255)
    |> unique_constraint(:daytona_sandbox_id,
      name: :playgithub_sandboxes_daytona_sandbox_id_index
    )
  end

  @doc """
  Changeset for updating internal PlayGithub workflow status.
  """
  def status_changeset(%__MODULE__{} = sandbox, status) when status in @statuses do
    sandbox
    |> change(
      status: status,
      status_started_at: DateTime.utc_now(:second),
      status_error: nil
    )
    |> validate_required([:status])
  end

  @doc """
  Changeset for recording failed PlayGithub workflow status with an error.
  """
  def failure_status_changeset(%__MODULE__{} = sandbox, status, error)
      when status in @failure_statuses and is_binary(error) do
    sandbox
    |> change(
      status: status,
      status_started_at: DateTime.utc_now(:second),
      status_error: error
    )
    |> validate_required([:status, :status_error])
    |> validate_length(:status_error, min: 1, max: 1_000)
  end

  def by_github_url(scope, github_url) do
    user_id = Accounts.scope_user_id(scope)

    from(s in __MODULE__, where: s.user_id == ^user_id and s.github_url == ^github_url)
  end

  def by_daytona_sandbox_id(scope, daytona_sandbox_id) do
    user_id = Accounts.scope_user_id(scope)

    from(s in __MODULE__,
      where: s.user_id == ^user_id and s.daytona_sandbox_id == ^daytona_sandbox_id
    )
  end
end
