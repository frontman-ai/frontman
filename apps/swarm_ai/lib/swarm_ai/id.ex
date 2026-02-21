defmodule SwarmAi.Id do
  @moduledoc """
  Generates prefixed UUIDv7 identifiers for entities in the swarm system.
  """

  @type t() :: String.t()

  @doc """
  Generates a new ID with the given prefix.

  Returns a string in the format `prefix_uuid`.

  ## Examples

      iex> SwarmAi.Id.generate("agent")
      "agent_01HZQW8K3X5YZ7..."

  """
  @spec generate(String.t()) :: t()
  def generate(prefix) do
    uuid = UUIDv7.generate()
    "#{prefix}_#{uuid}"
  end
end
