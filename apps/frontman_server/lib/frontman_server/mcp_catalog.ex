defmodule FrontmanServer.MCPCatalog do
  @moduledoc false

  alias FrontmanServer.Tools.MCP, as: MCPTool
  alias ModelContextProtocol, as: MCP

  @spec start() :: {map(), map()}
  def start do
    request_id = System.unique_integer([:positive])

    {%{status: :discovering, request_id: request_id, timer: nil, tools: []},
     MCP.discover_request(request_id)}
  end

  @spec put_timer(map(), reference()) :: map()
  def put_timer(state, timer) when is_reference(timer), do: %{state | timer: timer}

  @spec cancel_timer(map()) :: map()
  def cancel_timer(%{timer: nil} = state), do: state

  def cancel_timer(%{timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | timer: nil}
  end

  @spec response_method(map(), String.t() | integer()) :: String.t() | nil
  def response_method(%{request_id: request_id, status: :discovering}, request_id),
    do: "server/discover"

  def response_method(%{request_id: request_id, status: :listing}, request_id), do: "tools/list"
  def response_method(_state, _request_id), do: nil

  @spec handle_response(map(), String.t() | integer(), map()) ::
          {:request, map(), map()} | {:ready, map()} | {:error, map(), String.t()} | :unknown
  def handle_response(%{request_id: id, status: :discovering} = state, id, result) do
    case MCP.validate_discovery_compatibility(result) do
      :ok ->
        request_id = System.unique_integer([:positive])
        state = %{state | status: :listing, request_id: request_id, timer: nil}
        {:request, state, MCP.list_tools_request(request_id)}

      {:error, reason} ->
        {:error, %{state | status: :failed, request_id: nil, timer: nil}, reason}
    end
  end

  def handle_response(%{request_id: id, status: :listing} = state, id, result) do
    case Map.fetch!(result, "tools") do
      tools when length(tools) <= 256 ->
        {:ready,
         %{state | status: :ready, request_id: nil, timer: nil, tools: MCPTool.from_maps(tools)}}

      _tools ->
        {:error, %{state | status: :failed, request_id: nil, timer: nil, tools: []},
         "MCP catalog tool limit exceeded (maximum 256)"}
    end
  end

  def handle_response(_state, _request_id, _result), do: :unknown

  @spec handle_error(map(), String.t() | integer(), map()) ::
          {:error, map(), String.t()} | :unknown
  def handle_error(%{request_id: id} = state, id, _error) do
    {:error, %{state | status: :failed, request_id: nil, timer: nil}, "MCP error response"}
  end

  def handle_error(_state, _request_id, _error), do: :unknown
end
