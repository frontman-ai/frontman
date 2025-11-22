defmodule ReqLLM.Test.ChunkCollector do
  @moduledoc """
  Agent-based collector for streaming HTTP chunks.

  Test-only module for collecting binary chunks with microsecond timestamps
  during fixture recording. Replaces Process dictionary-based capture with
  explicit, testable state management.

  ## Workflow

  1. Start collector: `{:ok, pid} = ChunkCollector.start_link()`
  2. Add chunks as they arrive: `ChunkCollector.add_chunk(pid, binary)`
  3. Retrieve all chunks: `ChunkCollector.finish(pid)`

  ## Examples

      # Start collector
      {:ok, collector} = ChunkCollector.start_link()

      # Collect chunks
      ChunkCollector.add_chunk(collector, "data: chunk1\\n\\n")
      Process.sleep(10)
      ChunkCollector.add_chunk(collector, "data: chunk2\\n\\n")

      # Get results
      chunks = ChunkCollector.finish(collector)
      # => [
      #   %{bin: "data: chunk1\\n\\n", t_us: 0},
      #   %{bin: "data: chunk2\\n\\n", t_us: 10234}
      # ]
  """

  use Agent

  @type chunk :: %{bin: binary(), t_us: non_neg_integer()}
  @type state :: %{
          chunks: [chunk()],
          start_time: integer()
        }

  @doc """
  Start a new chunk collector.

  Initializes with empty chunk list and captures start time for relative timestamps.

  ## Examples

      {:ok, pid} = ChunkCollector.start_link()
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Agent.start_link(fn ->
      %{
        chunks: [],
        start_time: System.monotonic_time(:microsecond)
      }
    end)
  end

  @doc """
  Start a named chunk collector.

  Useful for debugging or when you need to reference the collector by name.

  ## Examples

      {:ok, pid} = ChunkCollector.start_link(name: :my_collector)
      ChunkCollector.add_chunk(:my_collector, "chunk")
  """
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts) when is_list(opts) do
    Agent.start_link(
      fn ->
        %{
          chunks: [],
          start_time: System.monotonic_time(:microsecond)
        }
      end,
      opts
    )
  end

  @doc """
  Add a chunk to the collector.

  Automatically calculates relative timestamp from start time.

  ## Examples

      ChunkCollector.add_chunk(collector, "data: {\\"delta\\": \\"Hi\\"}\\n\\n")
      :ok
  """
  @spec add_chunk(pid() | atom(), binary()) :: :ok
  def add_chunk(collector, binary) when is_binary(binary) do
    Agent.update(collector, fn state ->
      timestamp_us = System.monotonic_time(:microsecond) - state.start_time
      chunk = %{bin: binary, t_us: timestamp_us}
      %{state | chunks: [chunk | state.chunks]}
    end)
  end

  @doc """
  Get all collected chunks in chronological order.

  Does not stop the collector - use `finish/1` if you want to stop it.

  ## Examples

      chunks = ChunkCollector.get_chunks(collector)
      # => [%{bin: "first", t_us: 0}, %{bin: "second", t_us: 1234}]
  """
  @spec get_chunks(pid() | atom()) :: [chunk()]
  def get_chunks(collector) do
    Agent.get(collector, fn state ->
      Enum.reverse(state.chunks)
    end)
  end

  @doc """
  Get the number of chunks collected.

  ## Examples

      ChunkCollector.count(collector)
      # => 42
  """
  @spec count(pid() | atom()) :: non_neg_integer()
  def count(collector) do
    Agent.get(collector, fn state ->
      length(state.chunks)
    end)
  end

  @doc """
  Check if any chunks have been collected.

  ## Examples

      ChunkCollector.empty?(collector)
      # => false
  """
  @spec empty?(pid() | atom()) :: boolean()
  def empty?(collector) do
    count(collector) == 0
  end

  @doc """
  Get total size in bytes of all collected chunks.

  ## Examples

      ChunkCollector.total_bytes(collector)
      # => 4096
  """
  @spec total_bytes(pid() | atom()) :: non_neg_integer()
  def total_bytes(collector) do
    Agent.get(collector, fn state ->
      Enum.reduce(state.chunks, 0, fn chunk, acc ->
        acc + byte_size(chunk.bin)
      end)
    end)
  end

  @doc """
  Clear all collected chunks without stopping the collector.

  ## Examples

      ChunkCollector.clear(collector)
      :ok
  """
  @spec clear(pid() | atom()) :: :ok
  def clear(collector) do
    Agent.update(collector, fn state ->
      %{state | chunks: [], start_time: System.monotonic_time(:microsecond)}
    end)
  end

  @doc """
  Get all chunks and stop the collector.

  This is the typical way to finish collection - retrieves chunks and
  cleans up the Agent process.

  ## Examples

      chunks = ChunkCollector.finish(collector)
      # Collector is now stopped
  """
  @spec finish(pid() | atom()) :: [chunk()]
  def finish(collector) do
    chunks = get_chunks(collector)
    Agent.stop(collector, :normal)
    chunks
  end

  @doc """
  Stop the collector without retrieving chunks.

  ## Examples

      ChunkCollector.stop(collector)
      :ok
  """
  @spec stop(pid() | atom()) :: :ok
  def stop(collector) do
    Agent.stop(collector, :normal)
  end
end
