defmodule SwarmAi.Testing do
  @moduledoc """
  Test helpers for SwarmAi framework tests.

  Provides common fixtures, agents, and LLM mocks for testing SwarmAi execution.

  ## Usage

      use SwarmAi.Testing, async: true

      @tag echo_agent: true
      test "executes agent", %{echo_agent: agent} do
        {:ok, result, _loop_id} = SwarmAi.run_blocking(agent, "Hello", fn _ -> {:ok, ""} end)
        assert "Echo: Hello" = result
      end

  ## Available fixtures

  All fixtures are opt-in via setup tags:

  - `:echo_agent` - Agent with EchoLLM that echoes back messages
  - `:error_agent` - Agent with ErrorLLM that returns errors
  - `:mock_llm` - Configurable MockLLM (use `mock_llm: response`)
  """

  use ExUnit.CaseTemplate

  alias SwarmAi.LLM

  # --- Test Agents ---

  defmodule TestAgent do
    @moduledoc false
    defstruct [:name, :llm]
  end

  defimpl SwarmAi.Agent, for: SwarmAi.Testing.TestAgent do
    def system_prompt(%{name: name}), do: "You are #{name}"
    def llm(%{llm: llm}), do: llm
    def init(_), do: {:ok, %{}, []}
    def should_terminate?(_, _, _), do: false
  end

  # --- Test LLM Implementations ---

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
    defstruct response: "default response", delay_ms: 0, model: "mock"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.MockLLM do
    alias SwarmAi.LLM.{Chunk, Usage}

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
          do: [Chunk.token(response.content) | chunks],
          else: chunks

      chunks =
        Enum.reduce(response.tool_calls || [], chunks, fn tc, acc ->
          [Chunk.tool_call_end(tc) | acc]
        end)

      chunks =
        if response.usage, do: [Chunk.usage(to_usage(response.usage)) | chunks], else: chunks

      chunks = [Chunk.done(response.finish_reason || :stop) | chunks]
      Enum.reverse(chunks)
    end

    defp to_usage(%Usage{} = u), do: u

    defp to_usage(%{input_tokens: i, output_tokens: o}),
      do: %Usage{input_tokens: i, output_tokens: o}

    defp default_usage, do: %{input_tokens: 10, output_tokens: 5}
  end

  defmodule EchoLLM do
    @moduledoc """
    LLM that echoes the user message with "Echo: " prefix.
    """
    defstruct model: "echo"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.EchoLLM do
    alias SwarmAi.LLM.{Chunk, Usage}

    def stream(_client, messages, _opts) do
      user_msg = Enum.find(messages, &(&1.role == :user))
      text_content = SwarmAi.Message.text(user_msg)
      content = "Echo: #{text_content}"

      chunks = [
        Chunk.token(content),
        Chunk.usage(%Usage{input_tokens: 5, output_tokens: 3}),
        Chunk.done(:stop)
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
    propagates through Task -> ExecutionMonitor -> PubSub.

    Unlike ErrorLLM (which fails at the stream/3 return level), this mock
    returns {:ok, stream} and the error only surfaces when the stream is consumed.
    """
    defstruct error_message: "LLM API error", model: "stream-error"
  end

  defimpl SwarmAi.LLM, for: SwarmAi.Testing.StreamErrorLLM do
    def stream(%{error_message: message}, _messages, _opts) do
      # Return a lazy stream that raises when consumed, matching
      # the real LLMClient.to_swarm_chunk(%{type: :error, text: text}) behavior
      error_stream =
        Stream.resource(
          fn -> :init end,
          fn :init -> raise message end,
          fn _ -> :ok end
        )

      {:ok, error_stream}
    end
  end

  # --- Setup ---

  using do
    quote do
      import SwarmAi.Testing
      alias SwarmAi.Testing.EchoLLM
      alias SwarmAi.Testing.ErrorLLM
      alias SwarmAi.Testing.MockLLM
      alias SwarmAi.Testing.StreamErrorLLM
      alias SwarmAi.Testing.TestAgent
      alias SwarmAi.LLM
      alias SwarmAi.ToolCall
      alias SwarmAi.ToolResult
    end
  end

  setup context do
    fixtures = build_fixtures(context)
    {:ok, fixtures}
  end

  # --- Fixture Builders ---

  defp build_fixtures(context) do
    context
    |> maybe_add_mock_llm()
    |> maybe_add_echo_agent()
    |> maybe_add_error_agent()
  end

  defp maybe_add_mock_llm(%{mock_llm: response} = context) when is_map(response) do
    llm = struct!(MockLLM, response)
    Map.put(context, :mock_llm, llm)
  end

  defp maybe_add_mock_llm(%{mock_llm: response} = context) do
    Map.put(context, :mock_llm, %MockLLM{response: response})
  end

  defp maybe_add_mock_llm(context), do: context

  defp maybe_add_echo_agent(%{echo_agent: true} = context) do
    agent = %TestAgent{name: "EchoBot", llm: %EchoLLM{}}
    Map.put(context, :echo_agent, agent)
  end

  defp maybe_add_echo_agent(context), do: context

  defp maybe_add_error_agent(%{error_agent: error} = context) do
    agent = %TestAgent{name: "ErrorBot", llm: %ErrorLLM{error: error}}
    Map.put(context, :error_agent, agent)
  end

  defp maybe_add_error_agent(context), do: context

  # --- Helper Functions ---

  @doc """
  Creates a test agent with the given LLM client.
  """
  def test_agent(llm, name \\ "TestBot") do
    %TestAgent{name: name, llm: llm}
  end

  @doc """
  Creates a mock LLM with the given response.
  """
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
  def tool_result(id_or_tool_call, content, is_error \\ false)

  def tool_result(%SwarmAi.ToolCall{id: id}, content, is_error) do
    SwarmAi.ToolResult.make(id, content, is_error)
  end

  def tool_result(id, content, is_error) when is_binary(id) do
    SwarmAi.ToolResult.make(id, content, is_error)
  end
end
