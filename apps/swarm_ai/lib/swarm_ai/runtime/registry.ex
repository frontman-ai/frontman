defmodule SwarmAi.Runtime.Registry do
  @moduledoc false

  def child_spec(runtime) when is_atom(runtime) do
    {Registry, keys: :unique, name: name(runtime)}
  end

  def name(runtime) when is_atom(runtime), do: :"#{runtime}.Registry"

  def via(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    {:via, Registry, {name(runtime), task_id}}
  end

  def lookup(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    Registry.lookup(name(runtime), task_id)
  end

  def unregister(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    Registry.unregister(name(runtime), task_id)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, :noproc -> :ok
  end
end
