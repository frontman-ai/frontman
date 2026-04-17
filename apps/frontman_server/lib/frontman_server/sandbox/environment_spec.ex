defmodule FrontmanServer.Sandbox.EnvironmentSpec do
  @moduledoc """
  Input to Provider.create/1 — everything needed to provision a sandbox VM.

  Validated at the boundary via NimbleOptions. Ephemeral — only used at
  creation time. After that the provider ref string is sufficient for
  all operations.
  """

  @enforce_keys [:name, :image, :devcontainer]
  defstruct [:name, :image, :devcontainer, env: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          image: String.t(),
          devcontainer: map(),
          env: %{String.t() => String.t()}
        }

  @schema [
    name: [
      type: :string,
      required: true,
      doc: "Human-readable sandbox name (e.g., \"issue-123\")."
    ],
    image: [
      type: :string,
      required: true,
      doc: "OCI image reference for the VM base."
    ],
    devcontainer: [
      type: {:map, :string, :any},
      required: true,
      doc: "Raw parsed devcontainer.json — passed through to msb."
    ],
    env: [
      type: {:map, :string, :string},
      default: %{},
      doc: "Environment variables for the VM. Caller merges all vars before constructing."
    ]
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @schema) do
      {:ok, validated} ->
        spec = struct!(__MODULE__, validated)

        case validate_name(spec) do
          :ok -> {:ok, spec}
          {:error, _} = error -> error
        end

      {:error, _} = error ->
        error
    end
  end

  defp validate_name(%__MODULE__{name: name}) when byte_size(name) == 0 do
    {:error, %NimbleOptions.ValidationError{key: :name, message: "must be a non-empty string"}}
  end

  defp validate_name(%__MODULE__{}), do: :ok
end
