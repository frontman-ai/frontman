# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.RepositorySandbox do
  @moduledoc """
  Repository sandbox aggregate for PlayGithub.
  """

  alias FrontmanServer.PlayGithub.GithubReference

  @repo_url_label "frontman.playgithub.repo_url"
  @lifecycle_label "frontman.playgithub.lifecycle"
  @lifecycle_started_at_label "frontman.playgithub.lifecycle_started_at"
  @lifecycle_error_label "frontman.playgithub.lifecycle_error"
  @dev_server_url_label "frontman.playgithub.dev_server_url"
  @dev_server_port_label "frontman.playgithub.dev_server_port"

  @lifecycles ~w(
    sandbox_created sandbox_starting clone_starting clone_finished clone_failed
    install_starting install_finished install_failed dev_server_starting
    dev_server_started dev_server_failed
  )a

  @type provider_state :: :started | :starting | :stopped | :archived

  @type lifecycle ::
          :sandbox_created
          | :sandbox_starting
          | :clone_starting
          | :clone_finished
          | :clone_failed
          | :install_starting
          | :install_finished
          | :install_failed
          | :dev_server_starting
          | :dev_server_started
          | :dev_server_failed

  @type t :: %__MODULE__{
          github_reference: GithubReference.t(),
          id: String.t(),
          name: String.t(),
          provider_state: provider_state(),
          lifecycle: lifecycle(),
          lifecycle_started_at: integer() | nil,
          lifecycle_error: String.t() | nil,
          dev_server_url: String.t() | nil
        }

  @enforce_keys [:github_reference, :id, :name, :provider_state, :lifecycle]
  defstruct [
    :github_reference,
    :id,
    :name,
    :provider_state,
    :lifecycle,
    :lifecycle_started_at,
    :lifecycle_error,
    :dev_server_url
  ]

  def repo_url_label, do: @repo_url_label

  def sandbox_name(%GithubReference{} = github_reference) do
    github_reference
    |> GithubReference.repository_identity()
    |> sandbox_name_for_identity()
  end

  def initial_labels(%GithubReference{} = github_reference),
    do: labels(github_reference, :sandbox_created)

  def labels(%GithubReference{} = github_reference, lifecycle, opts \\ []) do
    %{
      @repo_url_label => GithubReference.repository_url(github_reference),
      @lifecycle_label => Atom.to_string(lifecycle)
    }
    |> put_optional(@lifecycle_started_at_label, Keyword.get(opts, :started_at))
    |> put_optional(@lifecycle_error_label, Keyword.get(opts, :error))
    |> put_optional(@dev_server_url_label, Keyword.get(opts, :dev_server_url))
    |> put_dev_server_port(Keyword.get(opts, :dev_server_url))
  end

  def lifecycle_from_labels(labels) when is_map(labels) do
    labels
    |> Map.get(@lifecycle_label, "sandbox_created")
    |> lifecycle_from_label(labels)
  end

  def provider_state("started"), do: {:ok, :started}
  def provider_state("starting"), do: {:ok, :starting}
  def provider_state("stopped"), do: {:ok, :stopped}
  def provider_state("archived"), do: {:ok, :archived}
  def provider_state(state), do: {:error, {:unknown_daytona_sandbox_state, state}}

  defp lifecycle_from_label(label, labels) do
    case Enum.find(@lifecycles, &(Atom.to_string(&1) == label)) do
      nil ->
        {:error, {:unknown_repository_sandbox_lifecycle, label}}

      lifecycle ->
        {:ok, lifecycle, started_at(labels), Map.get(labels, @lifecycle_error_label),
         Map.get(labels, @dev_server_url_label)}
    end
  end

  defp started_at(labels) do
    case Map.get(labels, @lifecycle_started_at_label) do
      nil -> nil
      value -> parse_started_at(value)
    end
  end

  defp parse_started_at(value) when is_binary(value) do
    case Integer.parse(value) do
      {started_at, ""} -> started_at
      _invalid -> nil
    end
  end

  defp put_optional(labels, _label, nil), do: labels
  defp put_optional(labels, _label, ""), do: labels
  defp put_optional(labels, label, value), do: Map.put(labels, label, to_string(value))

  defp put_dev_server_port(labels, nil), do: labels
  defp put_dev_server_port(labels, _url), do: Map.put(labels, @dev_server_port_label, "4321")

  defp sandbox_name_for_identity(identity) do
    hash =
      :sha256
      |> :crypto.hash(identity)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "playgithub-#{hash}"
  end
end
