defmodule FrontmanServer.MCPTerminalRequests do
  @moduledoc false

  @capacity 4_096
  @retention_ms 900_000

  @type terminal_record :: %{
          id: String.t() | integer(),
          method: String.t(),
          kind: term(),
          reason: term(),
          terminal_time_ms: integer(),
          former_owner: pid()
        }

  @spec remember([terminal_record()], map(), integer()) :: [terminal_record()]
  def remember(records, attributes, now_ms) when is_list(records) and is_integer(now_ms) do
    record = %{
      id: Map.fetch!(attributes, :id),
      method: Map.fetch!(attributes, :method),
      kind: Map.fetch!(attributes, :kind),
      reason: Map.fetch!(attributes, :reason),
      terminal_time_ms: now_ms,
      former_owner: Map.fetch!(attributes, :former_owner)
    }

    records
    |> prune(now_ms)
    |> Enum.reject(&same_id?(&1.id, record.id))
    |> then(&[record | &1])
    |> Enum.take(@capacity)
  end

  @spec classify([terminal_record()], String.t() | integer(), integer()) ::
          {:duplicate | :late | :unknown, terminal_record() | nil, [terminal_record()]}
  def classify(records, id, now_ms) when is_list(records) and is_integer(now_ms) do
    records = prune(records, now_ms)

    case Enum.find(records, &same_id?(&1.id, id)) do
      %{reason: reason} = record
      when reason in [:response, :error_response, :malformed_response] ->
        {:duplicate, record, records}

      %{} = record ->
        {:late, record, records}

      nil ->
        {:unknown, nil, records}
    end
  end

  defp prune(records, now_ms) do
    Enum.filter(records, fn record ->
      now_ms - record.terminal_time_ms <= @retention_ms
    end)
  end

  defp same_id?(left, right), do: left === right
end
