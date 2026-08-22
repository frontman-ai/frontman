# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomLlmEndpoint do
  @moduledoc """
  A user-defined OpenAI-compatible LLM endpoint.
  The optional API key is encrypted at rest using FrontmanServer.Vault.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_llm_endpoints" do
    field(:name, :string)
    field(:base_url, :string)
    field(:api_key, FrontmanServer.Encrypted.Binary)

    belongs_to(:user, User)

    has_many(:models, FrontmanServer.Providers.CustomLlmModel,
      foreign_key: :endpoint_id,
      on_delete: :delete_all
    )

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating an endpoint.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  def changeset(endpoint, attrs) do
    endpoint
    |> cast(attrs, [:name, :base_url, :api_key])
    |> validate_required([:name, :base_url])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_length(:base_url, min: 1, max: 512)
    |> validate_base_url()
    |> unique_constraint([:user_id, :name])
  end

  # Requires a parseable URL with an http/https scheme and a host. Raw IPs and
  # localhost are allowed; anything without a scheme + host is rejected.
  defp validate_base_url(changeset) do
    validate_change(changeset, :base_url, fn :base_url, value ->
      case URI.new(value) do
        {:ok, %URI{scheme: scheme, host: host}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _ ->
          [base_url: "must be a valid http(s) URL"]
      end
    end)
  end

  @doc """
  Query helpers.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from(e in query, where: e.user_id == ^user_id)
  end

  def for_user_and_name(query \\ __MODULE__, user_id, name) do
    from(e in query, where: e.user_id == ^user_id and e.name == ^name)
  end
end
