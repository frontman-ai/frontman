defmodule SwarmAi.Runtime.Registry do
  @moduledoc false

  def child_spec(runtime) when is_atom(runtime) do
    {Registry, keys: :unique, name: name(runtime)}
  end

  def name(runtime) when is_atom(runtime), do: :"#{runtime}.Registry"

  def via(runtime, key) when is_atom(runtime) and is_binary(key) do
    {:via, Registry, {name(runtime), key}}
  end

  def lookup(runtime, key) when is_atom(runtime) and is_binary(key) do
    Registry.lookup(name(runtime), key)
  end

  def mark_finishing(runtime, key) when is_atom(runtime) and is_binary(key) do
    {:finishing, _previous} =
      Registry.update_value(name(runtime), key, fn _ -> :finishing end)

    :ok
  end
end
