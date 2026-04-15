defmodule FrontmanServer.Sandbox.EnvironmentSpec do
  @moduledoc """
  The parsed contents of a repo's devcontainer.json.

  Stored as JSONB on the project. Consumed by the provisioning
  pipeline to build a VM image via envbuilder.
  """

  @derive Jason.Encoder
  defstruct [:contents]

  @type t :: %__MODULE__{contents: map()}

  @spec new(map()) :: {:ok, t()} | {:error, :empty_devcontainer}
  def new(contents) when is_map(contents) and map_size(contents) > 0,
    do: {:ok, %__MODULE__{contents: contents}}

  def new(_), do: {:error, :empty_devcontainer}
end
