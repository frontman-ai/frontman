defmodule FrontmanServer.ToolRegistry do
  @moduledoc """
  Generic tool registry.
  
  Maps tool names to their event modules. Simple map-based approach.
  Each domain registers its tools here.
  """
  
  # Simple map: tool_name => event_module
  # nil means tool doesn't produce events (e.g., query tools)
  @registry %{
    "todo_add" => FrontmanServer.Tasks.Todos.Tools.TodoAdded,
    "todo_update" => FrontmanServer.Tasks.Todos.Tools.TodoUpdated,
    "todo_remove" => FrontmanServer.Tasks.Todos.Tools.TodoRemoved,
    "todo_list" => nil
  }
  
  @doc """
  Returns the event module for a tool name, or nil if tool doesn't produce events.
  """
  @spec event_module(String.t()) :: module() | nil
  def event_module(tool_name) when is_binary(tool_name) do
    Map.get(@registry, tool_name)
  end
  
  @doc """
  Checks if a tool produces events.
  """
  @spec produces_events?(String.t()) :: boolean()
  def produces_events?(tool_name) when is_binary(tool_name) do
    case event_module(tool_name) do
      nil -> false
      _ -> true
    end
  end
end
