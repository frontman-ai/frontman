defmodule FrontmanServer.SwarmCase do
  @moduledoc """
  Test case for Swarm framework tests.

  Provides common fixtures, agents, and LLM mocks for testing Swarm execution.

  ## Usage

      use FrontmanServer.SwarmCase, async: true

      @tag echo_agent: true
      test "executes agent", %{echo_agent: agent} do
        {:ok, execution} = Swarm.start(agent, "Hello")
        assert {:ok, "Echo: Hello"} = Swarm.await(execution)
      end

  ## Available fixtures

  All fixtures are opt-in via setup tags:

  - `:echo_agent` - Agent with EchoLLM that echoes back messages
  - `:error_agent` - Agent with ErrorLLM that returns errors
  - `:mock_llm` - Configurable MockLLM (use `mock_llm: response`)
  - `:execute_opts` - Standard ExecuteOpts with event collector

  ## Event collection

  Events are sent to the subscriber as `{:swarm, execution_id, event}` messages:

      @tag echo_agent: true
      test "emits events", %{echo_agent: agent} do
        {:ok, execution} = Swarm.start(agent, "Test")
        assert_receive {:swarm, _, %Swarm.Events.Started{}}, 1000
      end
  """

  use ExUnit.CaseTemplate

  alias Swarm.{LLM, ExecuteOpts, Events}

  # --- Test Agents ---

  defmodule TestAgent do
    @moduledoc false
    defstruct [:name, :llm]
  end

  defimpl Swarm.Agent, for: FrontmanServer.SwarmCase.TestAgent do
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
    """
    defstruct response: "default response", delay_ms: 0
  end

  defimpl Swarm.LLM, for: FrontmanServer.SwarmCase.MockLLM do
    def call(%{response: response, delay_ms: delay}, _messages, _opts) do
      if delay > 0, do: Process.sleep(delay)

      case response do
        text when is_binary(text) ->
          {:ok, %LLM.Response{content: text, usage: default_usage(), raw: nil}}

        {:ok, _} = ok ->
          ok

        {:error, _} = error ->
          error

        fun when is_function(fun, 0) ->
          fun.()
      end
    end

    defp default_usage, do: %{input_tokens: 10, output_tokens: 5}
  end

  defmodule EchoLLM do
    @moduledoc """
    LLM that echoes the user message with "Echo: " prefix.
    """
    defstruct []
  end

  defimpl Swarm.LLM, for: FrontmanServer.SwarmCase.EchoLLM do
    def call(_client, messages, _opts) do
      user_msg = Enum.find(messages, &(&1.role == "user"))
      content = "Echo: #{user_msg.content}"

      {:ok,
       %LLM.Response{
         content: content,
         usage: %{input_tokens: 5, output_tokens: 3},
         raw: nil
       }}
    end
  end

  defmodule ErrorLLM do
    @moduledoc """
    LLM that always returns an error.
    """
    defstruct error: :llm_error
  end

  defimpl Swarm.LLM, for: FrontmanServer.SwarmCase.ErrorLLM do
    def call(%{error: error}, _messages, _opts), do: {:error, error}
  end

  # --- Setup ---

  using do
    quote do
      import FrontmanServer.SwarmCase
      alias Swarm.{Events, LLM, ExecutionProcess, ExecuteOpts}
      alias FrontmanServer.SwarmCase.{TestAgent, MockLLM, EchoLLM, ErrorLLM}
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
    |> maybe_add_execute_opts()
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

  defp maybe_add_execute_opts(%{execute_opts: true} = context) do
    opts = %ExecuteOpts{
      subscriber: self(),
      max_steps: 10,
      timeout_ms: 60_000,
      step_timeout_ms: 30_000
    }

    Map.put(context, :execute_opts, opts)
  end

  defp maybe_add_execute_opts(context), do: context

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
  Creates ExecuteOpts with subscriber set to the test process.
  """
  def test_opts(opts \\ []) do
    %ExecuteOpts{
      subscriber: Keyword.get(opts, :subscriber, self()),
      max_steps: Keyword.get(opts, :max_steps, 10),
      timeout_ms: Keyword.get(opts, :timeout_ms, 60_000),
      step_timeout_ms: Keyword.get(opts, :step_timeout_ms, 30_000)
    }
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
end
