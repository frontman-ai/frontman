defmodule FrontmanServer.JSONSchema do
  @moduledoc false

  @draft_2020_12 "https://json-schema.org/draft/2020-12/schema"
  @draft_2020_12_hash @draft_2020_12 <> "#"
  @max_depth 32
  @max_containers 1_024
  @timeout_ms 100
  @single_schema_keywords [
    "additionalProperties",
    "contains",
    "contentSchema",
    "else",
    "if",
    "items",
    "not",
    "propertyNames",
    "then",
    "unevaluatedItems",
    "unevaluatedProperties"
  ]
  @schema_map_keywords [
    "$defs",
    "definitions",
    "dependentSchemas",
    "patternProperties",
    "properties"
  ]
  @schema_list_keywords ["allOf", "anyOf", "oneOf", "prefixItems"]

  @type error ::
          :invalid_schema
          | :unsupported_dialect
          | :schema_depth_exceeded
          | :schema_container_limit_exceeded
          | :validation_failed
          | :validation_timed_out

  @spec validate_schema(map()) :: :ok | {:error, error()}
  def validate_schema(schema) when is_map(schema) do
    with :ok <- validate_dialect(schema),
         {:ok, _containers} <- measure(schema, 0, 0),
         :ok <- validate_schema_dialects(schema, 0),
         {:ok, _root} <- run_isolated(fn -> build(schema) end) do
      :ok
    end
  end

  @spec validate(map(), term()) :: :ok | {:error, error()}
  def validate(schema, value) when is_map(schema) do
    with :ok <- validate_dialect(schema),
         {:ok, _containers} <- measure(schema, 0, 0),
         :ok <- validate_schema_dialects(schema, 0),
         {:ok, root} <- run_isolated(fn -> build(schema) end),
         {:ok, :valid} <- run_isolated(fn -> validate_value(root, value) end) do
      :ok
    end
  end

  @doc false
  @spec validation_duration(non_neg_integer()) :: :accepted | :timed_out
  def validation_duration(elapsed_ms) when elapsed_ms <= @timeout_ms, do: :accepted
  def validation_duration(_elapsed_ms), do: :timed_out

  @doc false
  @spec validation_timeout_probe(non_neg_integer(), pid()) :: {:error, :validation_timed_out}
  def validation_timeout_probe(delay_ms, observer)
      when is_integer(delay_ms) and delay_ms >= 0 and is_pid(observer) do
    run_isolated(fn ->
      send(observer, {:validation_probe, self()})
      Process.sleep(delay_ms)
      send(observer, {:validation_probe_completed, self()})
      {:ok, :completed}
    end)
  end

  defp validate_dialect(schema) do
    case Map.get(schema, "$schema") do
      nil -> :ok
      @draft_2020_12 -> :ok
      @draft_2020_12_hash -> :ok
      _unsupported -> {:error, :unsupported_dialect}
    end
  end

  defp measure(_value, depth, _count) when depth > @max_depth,
    do: {:error, :schema_depth_exceeded}

  defp measure(value, depth, count) when is_map(value) do
    with {:ok, count} <- increment_container_count(count) do
      measure_children(Map.values(value), depth, count)
    end
  end

  defp measure(value, depth, count) when is_list(value) do
    with {:ok, count} <- increment_container_count(count) do
      measure_children(value, depth, count)
    end
  end

  defp measure(_value, _depth, count), do: {:ok, count}

  defp increment_container_count(count) when count < @max_containers, do: {:ok, count + 1}
  defp increment_container_count(_count), do: {:error, :schema_container_limit_exceeded}

  defp measure_children(children, depth, count) do
    Enum.reduce_while(children, {:ok, count}, fn child, {:ok, next_count} ->
      case measure(child, depth + 1, next_count) do
        {:ok, measured_count} -> {:cont, {:ok, measured_count}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_schema_dialects(_schema, depth) when depth > @max_depth,
    do: {:error, :schema_depth_exceeded}

  defp validate_schema_dialects(schema, depth) when is_map(schema) do
    with :ok <- validate_dialect(schema) do
      schema
      |> schema_children()
      |> validate_schema_dialect_children(depth + 1)
    end
  end

  defp validate_schema_dialects(schema, _depth) when is_boolean(schema), do: :ok
  defp validate_schema_dialects(_schema, _depth), do: :ok

  defp validate_schema_dialect_children(children, depth) do
    Enum.reduce_while(children, :ok, fn child, :ok ->
      case validate_schema_dialects(child, depth) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp schema_children(schema) do
    single_schema_children(schema) ++
      schema_map_children(schema) ++ schema_list_children(schema)
  end

  defp single_schema_children(schema) do
    Enum.flat_map(@single_schema_keywords, fn keyword ->
      case Map.fetch(schema, keyword) do
        {:ok, child} -> [child]
        :error -> []
      end
    end)
  end

  defp schema_map_children(schema) do
    Enum.flat_map(@schema_map_keywords, fn keyword ->
      case Map.get(schema, keyword) do
        children when is_map(children) -> Map.values(children)
        _missing_or_invalid -> []
      end
    end)
  end

  defp schema_list_children(schema) do
    Enum.flat_map(@schema_list_keywords, fn keyword ->
      case Map.get(schema, keyword) do
        children when is_list(children) -> children
        _missing_or_invalid -> []
      end
    end)
  end

  defp build(schema) do
    case JSV.build(schema, resolver: [], atoms: false, warnings: :silent) do
      {:ok, root} -> {:ok, root}
      {:error, _reason} -> {:error, :invalid_schema}
    end
  end

  defp validate_value(root, value) do
    case JSV.validate(value, root, cast: false) do
      {:ok, _value} -> {:ok, :valid}
      {:error, _reason} -> {:error, :validation_failed}
    end
  end

  defp run_isolated(operation) do
    caller = self()
    reference = make_ref()
    started_at = System.monotonic_time(:millisecond)

    {pid, monitor} =
      spawn_monitor(fn ->
        send(caller, {reference, operation.()})
      end)

    receive do
      {^reference, result} ->
        Process.demonitor(monitor, [:flush])

        case validation_duration(System.monotonic_time(:millisecond) - started_at) do
          :accepted -> result
          :timed_out -> {:error, :validation_timed_out}
        end

      {:DOWN, ^monitor, :process, ^pid, _reason} ->
        {:error, :invalid_schema}
    after
      @timeout_ms + 1 ->
        Process.exit(pid, :kill)

        receive do
          {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
        end

        {:error, :validation_timed_out}
    end
  end
end
