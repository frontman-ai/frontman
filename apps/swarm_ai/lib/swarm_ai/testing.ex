defmodule SwarmAi.Testing do
  @moduledoc """
  Test helpers for SwarmAi execution tests.

  Provides common fixtures, loops, and LLM mocks.

  ## Usage

      use SwarmAi.Testing, async: true

      @tag echo_execution: true
      test "runs loop", %{echo_execution: loop} do
        runtime = MyRuntime
        start_supervised!({SwarmAi, name: runtime})
        loop = %{loop | task_id: "task", messages: [SwarmAi.Message.user("Hello")]}
        {:ok, pid} = SwarmAi.run(runtime, loop)
        assert is_pid(pid)
      end

  ## Available fixtures

  All fixtures are opt-in via setup tags:

  - `:echo_execution` - Loop with EchoLLM that echoes back messages
  - `:error_execution` - Loop with ErrorLLM that returns errors
  - `:mock_llm` - Configurable MockLLM (use `mock_llm: response`)
  """

  use ExUnit.CaseTemplate

  alias SwarmAi.LLM

  defmodule MockLLM do
    @moduledoc """
    Configurable mock LLM for testing.

    Configure response via struct:
    - `response: "text"` - Returns text response
    - `response: {:error, reason}` - Returns error
    - `response: fn -> ... end` - Calls function for dynamic behavior
    - `delay_ms: integer` - Adds delay before response
    - `model: string` - Model name for telemetry
    """
    @type t :: %__MODULE__{
            response: term(),
            delay_ms: non_neg_integer(),
            model: String.t()
          }

    defstruct response: "default response", delay_ms: 0, model: "mock"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.MockLLM do
    alias ReqLLM.StreamChunk

    def stream(%{response: response, delay_ms: delay}, _messages, _opts) do
      if delay > 0, do: Process.sleep(delay)

      case response do
        text when is_binary(text) ->
          {:ok,
           response_to_stream(%LLM.Response{content: text, usage: default_usage(), raw: nil})}

        {:ok, %LLM.Response{} = resp} ->
          {:ok, response_to_stream(resp)}

        {:error, _} = error ->
          error

        fun when is_function(fun, 0) ->
          case fun.() do
            {:ok, %LLM.Response{} = resp} -> {:ok, response_to_stream(resp)}
            {:error, _} = error -> error
          end
      end
    end

    defp response_to_stream(%LLM.Response{} = response) do
      chunks = []

      chunks =
        if response.content && response.content != "",
          do: [StreamChunk.text(response.content) | chunks],
          else: chunks

      chunks =
        Enum.reduce(Enum.with_index(response.tool_calls || []), chunks, fn {tc, index}, acc ->
          [to_stream_chunk_tool_call(tc, index) | acc]
        end)

      chunks =
        if response.usage,
          do: [StreamChunk.meta(%{usage: response.usage}) | chunks],
          else: chunks

      chunks = [StreamChunk.meta(%{finish_reason: response.finish_reason || :stop}) | chunks]
      Enum.reverse(chunks)
    end

    defp to_stream_chunk_tool_call(%SwarmAi.ToolCall{} = tc, index) do
      args =
        case SwarmAi.ToolCall.parse_arguments(tc) do
          {:ok, arguments} -> arguments
          {:error, _reason} -> %{}
        end

      StreamChunk.tool_call(tc.name, args, %{id: tc.id, index: index})
    end

    defp default_usage, do: %{input_tokens: 10, output_tokens: 5}
  end

  defmodule EchoLLM do
    @moduledoc """
    LLM that echoes the user message with "Echo: " prefix.
    """
    defstruct model: "echo"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.EchoLLM do
    alias ReqLLM.StreamChunk

    def stream(_client, messages, _opts) do
      user_msg = Enum.find(messages, &match?(%SwarmAi.Message.User{}, &1))
      text_content = SwarmAi.Message.text(user_msg)
      content = "Echo: #{text_content}"

      chunks = [
        StreamChunk.text(content),
        StreamChunk.meta(%{usage: %{input_tokens: 5, output_tokens: 3}}),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      {:ok, chunks}
    end
  end

  defmodule ErrorLLM do
    @moduledoc """
    LLM that always returns an error.
    """
    defstruct error: :llm_error, model: "error"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.ErrorLLM do
    def stream(%{error: error}, _messages, _opts), do: {:error, error}
  end

  defmodule StreamErrorLLM do
    @moduledoc """
    LLM that returns a stream which raises mid-consumption.

    Simulates the real LLMClient behavior when ReqLLM emits an error chunk
    inside the stream (e.g., HTTP 400 for oversized images). The raise
    propagates through Task -> death watcher -> PubSub.

    Unlike ErrorLLM (which fails at the stream/3 return level), this mock
    returns {:ok, stream} and the error only surfaces when the stream is consumed.
    """
    defstruct error_message: "LLM API error", model: "stream-error"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.StreamErrorLLM do
    def stream(%{error_message: message}, _messages, _opts) do
      # Return a lazy stream that raises when consumed.
      error_stream =
        Stream.resource(
          fn -> :init end,
          fn :init -> raise message end,
          fn _ -> :ok end
        )

      {:ok, error_stream}
    end
  end

  defmodule StallingLLM do
    @moduledoc """
    LLM that delivers N chunks then hangs forever.

    Simulates an LLM provider that silently stalls mid-stream (no chunks,
    no TCP error). Used to test StreamStallTimeout detection.
    """
    defstruct chunks_before_stall: 2, model: "stalling"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.StallingLLM do
    alias ReqLLM.StreamChunk

    def stream(%{chunks_before_stall: n}, _messages, _opts) do
      stall_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            count when count < n ->
              {[StreamChunk.text("chunk-#{count}")], count + 1}

            _count ->
              # Hang forever to simulate a stalled provider.
              Process.sleep(:infinity)
              {:halt, nil}
          end,
          fn _ -> :ok end
        )

      {:ok, stall_stream}
    end
  end

  defmodule StreamTimeoutLLM do
    @moduledoc """
    LLM that returns a stream which exits with a GenServer.call timeout
    during consumption.

    Simulates the real scenario where the LLM provider stalls mid-stream:
    `StreamServer.next/2` issues a `GenServer.call` with a timeout slightly
    above Finch's `receive_timeout`. Under load the Finch timeout can take
    longer than that buffer to propagate, so the GenServer.call timeout
    fires first and exits the consumer process with
    `{:timeout, {GenServer, :call, [server, msg, timeout]}}`.
    """
    defstruct timeout: 151_000, model: "stream-timeout"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.StreamTimeoutLLM do
    def stream(%{timeout: timeout}, _messages, _opts) do
      stream =
        Stream.resource(
          fn -> :init end,
          fn :init ->
            exit({:timeout, {GenServer, :call, [self(), {:next, timeout}, timeout]}})
          end,
          fn _ -> :ok end
        )

      {:ok, stream}
    end
  end

  using do
    quote do
      import SwarmAi.Testing
      alias SwarmAi.LLM
      alias SwarmAi.Loop
      alias SwarmAi.Testing.EchoLLM
      alias SwarmAi.Testing.ErrorLLM
      alias SwarmAi.Testing.MockLLM
      alias SwarmAi.Testing.StallingLLM
      alias SwarmAi.Testing.StreamErrorLLM
      alias SwarmAi.Testing.StreamTimeoutLLM
      alias SwarmAi.ToolCall
      alias SwarmAi.ToolResult
    end
  end

  setup context do
    fixtures = build_fixtures(context)
    {:ok, fixtures}
  end

  defp build_fixtures(context) do
    context
    |> maybe_add_mock_llm()
    |> maybe_add_echo_execution()
    |> maybe_add_error_execution()
  end

  defp maybe_add_mock_llm(%{mock_llm: response} = context) when is_map(response) do
    llm = struct!(MockLLM, response)
    Map.put(context, :mock_llm, llm)
  end

  defp maybe_add_mock_llm(%{mock_llm: response} = context) do
    Map.put(context, :mock_llm, %MockLLM{response: response})
  end

  defp maybe_add_mock_llm(context), do: context

  defp maybe_add_echo_execution(%{echo_execution: true} = context) do
    execution = test_execution(%EchoLLM{}, "EchoBot")
    Map.put(context, :echo_execution, execution)
  end

  defp maybe_add_echo_execution(context), do: context

  defp maybe_add_error_execution(%{error_execution: error} = context) do
    execution = test_execution(%ErrorLLM{error: error}, "ErrorBot")
    Map.put(context, :error_execution, execution)
  end

  defp maybe_add_error_execution(context), do: context

  @doc """
  Creates a test execution with the given LLM client.
  """
  @spec test_execution(SwarmAi.LLM.t(), String.t(), keyword()) :: SwarmAi.Loop.t()
  def test_execution(llm, name \\ "TestBot", opts \\ []) do
    defaults = [
      task_id: "task-#{:erlang.unique_integer([:positive])}",
      turn_number: 1,
      llm: llm,
      messages: [SwarmAi.Message.system("You are #{name}"), SwarmAi.Message.user("Hello")],
      execute_tools: default_execute_tools(),
      dispatch_event: fn _event -> :ok end
    ]

    attrs =
      defaults
      |> Keyword.merge(opts)
      |> Keyword.new(fn
        {:id, id} -> {:task_id, id}
        entry -> entry
      end)

    SwarmAi.Loop.new(Map.new(attrs))
  end

  @doc false
  @spec default_execute_tools() :: SwarmAi.Loop.execute_tools()
  def default_execute_tools do
    fn tool_calls, task_supervisor ->
      executions =
        Enum.map(tool_calls, fn tc ->
          %SwarmAi.ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: {__MODULE__, :default_tool_run, []},
            on_timeout: {__MODULE__, :default_tool_timeout, []}
          }
        end)

      SwarmAi.ParallelExecutor.run(executions, task_supervisor)
    end
  end

  @doc false
  @spec default_tool_run(SwarmAi.ToolCall.t()) :: SwarmAi.ToolResult.t()
  def default_tool_run(tool_call), do: SwarmAi.ToolResult.make(tool_call.id, "done", false)

  @doc false
  @spec default_tool_timeout(SwarmAi.ToolCall.t(), term()) :: :ok
  def default_tool_timeout(_tool_call, _reason), do: :ok

  @doc """
  Creates a mock LLM with the given response.
  """
  @spec mock_llm(term(), keyword()) :: MockLLM.t()
  def mock_llm(response, opts \\ []) do
    struct!(MockLLM, [{:response, response} | opts])
  end

  @doc """
  Creates a multi-turn LLM that returns tool calls first, then completes.

  ## Example

      llm = multi_turn_llm([
        {:tool_calls, [%ToolCall{...}], "Let me check"},
        {:complete, "Here's the result"}
      ])
  """
  @spec multi_turn_llm([
          {:tool_calls, [SwarmAi.ToolCall.t()], String.t()}
          | {:complete, String.t()}
          | {:error, term()}
        ]) :: MockLLM.t()
  def multi_turn_llm(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)

    %MockLLM{
      response: fn ->
        case Agent.get_and_update(agent, fn
               [h | t] -> {h, t}
               [] -> {nil, []}
             end) do
          {:tool_calls, tcs, content} ->
            {:ok,
             %LLM.Response{
               content: content,
               tool_calls: tcs,
               usage: %{input_tokens: 10, output_tokens: 5},
               raw: nil
             }}

          {:complete, content} ->
            {:ok,
             %LLM.Response{
               content: content,
               tool_calls: [],
               usage: %{input_tokens: 10, output_tokens: 5},
               raw: nil
             }}

          {:error, reason} ->
            {:error, reason}

          nil ->
            {:error, :no_more_responses}
        end
      end
    }
  end

  @doc """
  Creates an LLM that returns tool calls on first call, then a final response.
  """
  @spec tool_then_complete_llm([SwarmAi.ToolCall.t()], String.t()) :: MockLLM.t()
  def tool_then_complete_llm(tool_calls, final_response) do
    multi_turn_llm([
      {:tool_calls, tool_calls, "Calling tools..."},
      {:complete, final_response}
    ])
  end

  @doc """
  Creates a ToolCall fixture with the given name and arguments.

  ## Examples

      tool_call("get_weather", %{"city" => "NYC"})
      tool_call("list_files", %{}, id: "call_123")
  """
  @spec tool_call(String.t(), map(), keyword()) :: SwarmAi.ToolCall.t()
  def tool_call(name, args \\ %{}, opts \\ []) do
    id = Keyword.get(opts, :id, "tc_#{:erlang.unique_integer([:positive])}")

    %SwarmAi.ToolCall{
      id: id,
      name: name,
      arguments: Jason.encode!(args)
    }
  end

  @doc """
  Creates a ToolResult fixture.

  Accepts either a ToolCall struct or a tool call ID string.

  ## Examples

      tc = tool_call("get_weather")
      tool_result(tc, "Sunny, 22°C")
      tool_result("call_123", "Error: not found", true)
  """
  @spec tool_result(SwarmAi.ToolCall.t() | String.t(), term(), boolean()) ::
          SwarmAi.ToolResult.t()
  def tool_result(id_or_tool_call, content, is_error \\ false)

  def tool_result(%SwarmAi.ToolCall{id: id}, content, is_error) do
    SwarmAi.ToolResult.make(id, content, is_error)
  end

  def tool_result(id, content, is_error) when is_binary(id) do
    SwarmAi.ToolResult.make(id, content, is_error)
  end
end
