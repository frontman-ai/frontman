defmodule FrontmanServer.MCPConnection do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.MCPConnectionState
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.ToolCallExecutionReference

  @registry FrontmanServer.MCPConnectionRegistry

  @spec topic(Scope.t()) :: String.t()
  def topic(%Scope{} = scope), do: "mcp_connection:#{scope.user.id}"

  @spec register(Scope.t()) :: {:ok, Ecto.UUID.t()}
  def register(%Scope{} = scope) do
    owner_connection_id = Ecto.UUID.generate()
    :ok = MCPConnectionState.register(self())

    case Registry.register(@registry, scope.user.id, %{
           rank: System.unique_integer([:monotonic, :positive]),
           owner_connection_id: owner_connection_id
         }) do
      {:ok, _pid} ->
        {:ok, owner_connection_id}

      {:error, reason} ->
        :ok = MCPConnectionState.unregister(self())
        {:error, reason}
    end
  end

  @spec own_connection_id(Scope.t()) :: Ecto.UUID.t()
  def own_connection_id(%Scope{} = scope), do: own_value(scope).owner_connection_id

  @spec owner_connection_id(Scope.t()) :: Ecto.UUID.t() | nil
  def owner_connection_id(%Scope{} = scope) do
    case owner(scope) do
      {:ok, _pid, value} -> value.owner_connection_id
      :unavailable -> nil
    end
  end

  @spec owner_pid(Scope.t()) :: pid() | nil
  def owner_pid(%Scope{} = scope) do
    case owner(scope) do
      {:ok, pid, _value} -> pid
      :unavailable -> nil
    end
  end

  @spec update_catalog(Scope.t(), :pending | :ready | :failed, list()) :: :ok | :not_owner
  def update_catalog(%Scope{} = scope, status, tools)
      when status in [:pending, :ready, :failed] and is_list(tools) do
    own_value(scope)
    :ok = MCPConnectionState.update_catalog(self(), status, tools)

    publish_if_owner(scope, self(), status, tools)
  end

  @spec update_project_context(Scope.t(), String.t(), :ready | :failed) :: :ok | :not_owner
  def update_project_context(%Scope{} = scope, task_id, status)
      when is_binary(task_id) and status in [:ready, :failed] do
    own_value(scope)
    :ok = MCPConnectionState.update_project_context(self(), task_id, status)

    case owner(scope) do
      {:ok, pid, _value} when pid == self() ->
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          topic(scope),
          {:mcp_project_context_ready, pid, task_id, status}
        )

      {:ok, _pid, _value} ->
        :not_owner

      :unavailable ->
        :not_owner
    end
  end

  @spec unregister(Scope.t()) :: :ok
  def unregister(%Scope{} = scope) do
    Registry.unregister(@registry, scope.user.id)
    :ok = MCPConnectionState.unregister(self())

    case owner(scope) do
      {:ok, pid, _value} -> send(pid, {:mcp_owner_departed, self()})
      :unavailable -> publish_unavailable(scope)
    end

    :ok
  end

  @spec successor_pid(Scope.t()) :: pid() | nil
  def successor_pid(%Scope{} = scope) do
    case owner(scope, self()) do
      {:ok, pid, _value} -> pid
      :unavailable -> nil
    end
  end

  @spec publish_unavailable(Scope.t()) :: :ok | :available
  def publish_unavailable(%Scope{} = scope) do
    case owner(scope) do
      :unavailable -> broadcast(scope, nil, :pending, [])
      {:ok, _pid, _value} -> :available
    end
  end

  @spec publish_own_catalog(Scope.t()) :: :ok | :not_owner
  def publish_own_catalog(%Scope{} = scope) do
    own_value(scope)

    case MCPConnectionState.catalog(self()) do
      {:ok, status, tools} -> publish_if_owner(scope, self(), status, tools)
      :unavailable -> raise "MCP connection state is unavailable"
    end
  end

  @spec catalog(Scope.t()) :: {:ok, :pending | :ready | :failed, list()} | :unavailable
  def catalog(%Scope{} = scope) do
    case owner(scope) do
      {:ok, pid, _value} ->
        case MCPConnectionState.catalog(pid) do
          {:ok, status, tools} -> {:ok, status, tools}
          :unavailable -> request_state_restore(pid)
        end

      :unavailable ->
        :unavailable
    end
  end

  @spec project_context(Scope.t(), String.t()) ::
          {:ok, pid(), :ready | :failed | :pending} | :unavailable
  def project_context(%Scope{} = scope, task_id) when is_binary(task_id) do
    case owner(scope) do
      {:ok, pid, _value} ->
        case MCPConnectionState.project_context(pid, task_id) do
          {:ok, status} -> {:ok, pid, status}
          :unavailable -> request_state_restore(pid)
        end

      :unavailable ->
        :unavailable
    end
  end

  @spec execute_tool(
          Scope.t(),
          ToolCallExecutionReference.t(),
          Interaction.ToolCall.t()
        ) ::
          :ok | :unavailable
  def execute_tool(
        %Scope{} = scope,
        %ToolCallExecutionReference{} = reference,
        %Interaction.ToolCall{} = tool_call
      ) do
    send_owner(scope, {:execute_mcp_tool, reference, tool_call})
  end

  @spec cancel_task(Scope.t(), String.t(), String.t()) :: :ok | :unavailable
  def cancel_task(%Scope{} = scope, task_id, reason)
      when is_binary(task_id) and is_binary(reason) do
    send_owner(scope, {:cancel_mcp_task, task_id, reason})
  end

  @spec cancel_tool(Scope.t(), String.t(), String.t(), String.t()) ::
          :claimed_cancelled | :not_found | :unavailable
  def cancel_tool(%Scope{} = scope, task_id, tool_call_id, reason)
      when is_binary(task_id) and is_binary(tool_call_id) and is_binary(reason) do
    case owner(scope) do
      {:ok, pid, _value} ->
        reference = make_ref()
        send(pid, {:cancel_mcp_tool, self(), reference, task_id, tool_call_id, reason})

        receive do
          {:mcp_tool_cancelled, ^reference, status} -> status
        after
          5_000 -> exit({:mcp_cancel_tool_timeout, task_id, tool_call_id})
        end

      :unavailable ->
        :unavailable
    end
  end

  @spec load_task(Scope.t(), String.t()) :: :ok | :unavailable
  def load_task(%Scope{} = scope, task_id) when is_binary(task_id) do
    send_owner(scope, {:load_mcp_task, task_id})
  end

  @spec hydrate_task(Scope.t(), String.t()) :: :ok | :unavailable
  def hydrate_task(%Scope{} = scope, task_id) when is_binary(task_id) do
    send_owner(scope, {:hydrate_mcp_task, task_id})
  end

  @spec forget_task(Scope.t(), String.t()) :: :local | :ok | :unavailable
  def forget_task(%Scope{} = scope, task_id) when is_binary(task_id) do
    case owner(scope) do
      {:ok, pid, _value} when pid == self() ->
        :local

      {:ok, pid, _value} ->
        reference = make_ref()
        send(pid, {:forget_mcp_task, self(), reference, task_id})

        receive do
          {:mcp_task_forgotten, ^reference} -> :ok
        after
          5_000 -> exit({:mcp_forget_task_timeout, task_id})
        end

      :unavailable ->
        :unavailable
    end
  end

  defp send_owner(scope, message) do
    case owner(scope) do
      {:ok, pid, _value} ->
        send(pid, message)
        :ok

      :unavailable ->
        :unavailable
    end
  end

  defp request_state_restore(pid) do
    send(pid, :restore_mcp_connection_state)
    :unavailable
  end

  defp owner(scope, excluded_pid \\ nil) do
    case @registry
         |> Registry.lookup(scope.user.id)
         |> Enum.filter(fn {pid, _value} -> Process.alive?(pid) and pid != excluded_pid end)
         |> Enum.min_by(&owner_rank/1, fn -> nil end) do
      {pid, value} -> {:ok, pid, value}
      nil -> :unavailable
    end
  end

  defp owner_rank({_pid, %{rank: rank}}), do: rank

  defp own_value(scope) do
    case Enum.find(Registry.lookup(@registry, scope.user.id), fn {pid, _value} ->
           pid == self()
         end) do
      {_pid, value} -> value
      nil -> raise "MCP connection is not registered"
    end
  end

  defp publish_if_owner(scope, pid, status, tools) do
    case owner(scope) do
      {:ok, ^pid, _value} -> broadcast(scope, pid, status, tools)
      {:ok, _other_pid, _value} -> :not_owner
      :unavailable -> :not_owner
    end
  end

  defp broadcast(scope, owner_pid, status, tools) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      topic(scope),
      {:mcp_catalog_updated, owner_pid, status, tools}
    )

    :ok
  end
end
