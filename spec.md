## Thin Slice: Simple Agent Execution

### What We're Building

A minimal end-to-end flow where:
1. App defines an agent (struct implementing protocol)
2. App calls `Swarm.execute(agent, message)`
3. Swarm runs a single LLM call
4. App gets the response back

No tools, no tool calling, no child agents. Just the skeleton we'll build on.

### Core Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   App                           Swarm                                       │
│                                                                             │
│   ┌─────────────────┐          ┌─────────────────────────────────────────┐ │
│   │ Agent Struct    │─────────▶│ ExecutionProcess                        │ │
│   │ (implements     │          │   │                                     │ │
│   │  Swarm.Agent)   │          │   ├── Loop.Runner.start()               │ │
│   └─────────────────┘          │   │     │                               │ │
│                                │   │     ▼                               │ │
│   ┌─────────────────┐          │   │   {loop, [{:call_llm, ...}]}       │ │
│   │ LLM Client      │◀─────────│   │     │                               │ │
│   │ (implements     │          │   │     ▼ interpret effect              │ │
│   │  Swarm.LLM)     │          │   │   Swarm.LLM.call(client, ...)      │ │
│   └─────────────────┘          │   │     │                               │ │
│          │                     │   │     ▼ async response                │ │
│          │                     │   ├── Loop.Runner.handle_llm_response() │ │
│          ▼                     │   │     │                               │ │
│   ┌─────────────────┐          │   │     ▼                               │ │
│   │ ReqLLM / OpenAI │          │   │   {loop, [{:complete, result}]}    │ │
│   │ / Mock          │          │   │     │                               │ │
│   └─────────────────┘          │   │     ▼ reply to caller               │ │
│                                │   └─────────────────────────────────────┘ │
│                                │                                           │
│   ┌─────────────────┐          │                                           │
│   │ on_event        │◀─────────│ {:emit_event, ...} effects               │
│   │ callback        │          │                                           │
│   └─────────────────┘          │                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Principle

**Loop.Runner is pure** — takes data, returns `{updated_loop, effects}`. No side effects.

**ExecutionProcess interprets effects** — side effects happen here.

---

## Implementation

### 1. Swarm.LLM (Protocol + Response)

```elixir
defmodule Swarm.LLM.Response do
  @type t :: %__MODULE__{
    content: String.t() | nil,
    usage: usage() | nil,
    raw: term()
  }

  @type usage :: %{
    input_tokens: non_neg_integer(),
    output_tokens: non_neg_integer()
  }

  defstruct [:content, :usage, :raw]
end

defprotocol Swarm.LLM do
  @spec call(t, messages :: [map()], opts :: keyword()) ::
    {:ok, Swarm.LLM.Response.t()} | {:error, term()}
  def call(client, messages, opts)
end
```

---

### 2. Swarm.Agent (Protocol)

```elixir
defprotocol Swarm.Agent do
  @spec system_prompt(t) :: String.t()
  def system_prompt(agent)

  @spec llm(t) :: Swarm.LLM.t()
  def llm(agent)
end
```

---

### 3. Swarm.Loop (Data)

```elixir
defmodule Swarm.Loop do
  @type status :: :ready | :running | :completed | :failed

  @type t :: %__MODULE__{
    id: String.t(),
    status: status(),
    steps: [Swarm.Loop.Step.t()],
    result: String.t() | nil,
    error: term() | nil
  }

  @enforce_keys [:id]
  defstruct [:id, :result, :error, status: :ready, steps: []]

  def new(id), do: %__MODULE__{id: id}
end

defmodule Swarm.Loop.Step do
  @type t :: %__MODULE__{
    number: pos_integer(),
    input_messages: [map()],
    content: String.t() | nil,
    usage: map() | nil,
    started_at: DateTime.t(),
    completed_at: DateTime.t() | nil,
    duration_ms: non_neg_integer() | nil
  }

  @enforce_keys [:number, :started_at]
  defstruct [:number, :content, :usage, :started_at, :completed_at, :duration_ms, input_messages: []]
end
```

---

### 4. Swarm.Effect (Boundary Type)

```elixir
defmodule Swarm.Effect do
  @type t ::
    | {:call_llm, client :: Swarm.LLM.t(), messages :: [map()]}
    | {:emit_event, Swarm.Events.event()}
    | {:complete, result :: String.t()}
    | {:fail, error :: term()}
end
```

---

### 5. Swarm.Events

```elixir
defmodule Swarm.Events do
  defmodule LoopStarted do
    @type t :: %__MODULE__{execution_id: String.t(), message: String.t()}
    defstruct [:execution_id, :message]
  end

  defmodule StepCompleted do
    @type t :: %__MODULE__{
      execution_id: String.t(),
      step_number: pos_integer(),
      content: String.t() | nil,
      duration_ms: non_neg_integer()
    }
    defstruct [:execution_id, :step_number, :content, :duration_ms]
  end

  defmodule ExecutionCompleted do
    @type t :: %__MODULE__{
      execution_id: String.t(),
      result: String.t(),
      total_steps: pos_integer()
    }
    defstruct [:execution_id, :result, :total_steps]
  end

  defmodule ExecutionFailed do
    @type t :: %__MODULE__{
      execution_id: String.t(),
      error: term()
    }
    defstruct [:execution_id, :error]
  end

  @type event :: LoopStarted.t() | StepCompleted.t() | ExecutionCompleted.t() | ExecutionFailed.t()
end
```

---

### 6. Swarm.Loop.Runner (Pure)

```elixir
defmodule Swarm.Loop.Runner do
  alias Swarm.{Loop, Effect, Events, Agent, LLM}
  alias Swarm.Loop.Step

  @spec start(Loop.t(), agent :: Swarm.Agent.t(), message :: String.t()) ::
    {Loop.t(), [Effect.t()]}
  def start(%Loop{status: :ready} = loop, agent, message) do
    system_prompt = Agent.system_prompt(agent)
    llm = Agent.llm(agent)

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: message}
    ]

    step = %Step{
      number: 1,
      input_messages: messages,
      started_at: DateTime.utc_now()
    }

    loop = %{loop | status: :running, steps: [step]}

    effects = [
      {:emit_event, %Events.LoopStarted{execution_id: loop.id, message: message}},
      {:call_llm, llm, messages}
    ]

    {loop, effects}
  end

  @spec handle_llm_response(Loop.t(), LLM.Response.t()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_response(%Loop{status: :running} = loop, %LLM.Response{} = response) do
    now = DateTime.utc_now()
    [step] = loop.steps

    step = %{step |
      content: response.content,
      usage: response.usage,
      completed_at: now,
      duration_ms: DateTime.diff(now, step.started_at, :millisecond)
    }

    loop = %{loop |
      status: :completed,
      steps: [step],
      result: response.content
    }

    effects = [
      {:emit_event, %Events.StepCompleted{
        execution_id: loop.id,
        step_number: step.number,
        content: step.content,
        duration_ms: step.duration_ms
      }},
      {:emit_event, %Events.ExecutionCompleted{
        execution_id: loop.id,
        result: response.content,
        total_steps: 1
      }},
      {:complete, response.content}
    ]

    {loop, effects}
  end

  @spec handle_llm_error(Loop.t(), term()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_error(%Loop{} = loop, error) do
    loop = %{loop | status: :failed, error: error}

    effects = [
      {:emit_event, %Events.ExecutionFailed{execution_id: loop.id, error: error}},
      {:fail, error}
    ]

    {loop, effects}
  end
end
```

---

### 7. Swarm.ExecutionContext (Runtime Config)

```elixir
defmodule Swarm.ExecutionContext do
  @type t :: %__MODULE__{
    id: String.t(),
    on_event: (Swarm.Events.event() -> :ok)
  }

  @enforce_keys [:id]
  defstruct [:id, on_event: &__MODULE__.noop/1]

  def noop(_event), do: :ok
end
```

---

### 8. Swarm.ExecutionProcess (Effect Interpreter)

```elixir
defmodule Swarm.ExecutionProcess do
  use GenServer, restart: :temporary

  alias Swarm.{Loop, Effect, LLM}
  alias Swarm.Loop.Runner

  defstruct [:loop, :agent, :ctx, :caller]

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def run(pid, message) do
    GenServer.call(pid, {:run, message}, :infinity)
  end

  # --- Server ---

  @impl true
  def init(opts) do
    state = %__MODULE__{
      loop: Loop.new(opts.ctx.id),
      agent: opts.agent,
      ctx: opts.ctx
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:run, message}, from, state) do
    {loop, effects} = Runner.start(state.loop, state.agent, message)
    state = %{state | loop: loop, caller: from}
    process_effects(effects, state)
  end

  @impl true
  def handle_info({ref, {:ok, %LLM.Response{} = response}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {loop, effects} = Runner.handle_llm_response(state.loop, response)
    process_effects(effects, %{state | loop: loop})
  end

  @impl true
  def handle_info({ref, {:error, error}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {loop, effects} = Runner.handle_llm_error(state.loop, error)
    process_effects(effects, %{state | loop: loop})
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    {loop, effects} = Runner.handle_llm_error(state.loop, {:llm_crashed, reason})
    process_effects(effects, %{state | loop: loop})
  end

  # --- Effect Interpreter ---

  defp process_effects([], state), do: {:noreply, state}

  defp process_effects([effect | rest], state) do
    case execute_effect(effect, state) do
      {:continue, new_state} -> process_effects(rest, new_state)
      {:reply, result, new_state} -> {:reply, result, new_state}
      {:stop, reason, new_state} -> {:stop, reason, new_state}
    end
  end

  defp execute_effect({:call_llm, client, messages}, state) do
    Task.async(fn -> LLM.call(client, messages, []) end)
    {:continue, state}
  end

  defp execute_effect({:emit_event, event}, state) do
    state.ctx.on_event.(event)
    {:continue, state}
  end

  defp execute_effect({:complete, result}, state) do
    GenServer.reply(state.caller, {:ok, result})
    {:stop, :normal, state}
  end

  defp execute_effect({:fail, error}, state) do
    GenServer.reply(state.caller, {:error, error})
    {:stop, :normal, state}
  end
end
```

---

### 9. Swarm (Entry Point)

```elixir
defmodule Swarm do
  alias Swarm.{ExecutionContext, ExecutionProcess}

  @spec execute(Swarm.Agent.t(), String.t(), keyword()) ::
    {:ok, String.t()} | {:error, term()}
  def execute(agent, message, opts \\ []) do
    ctx = %ExecutionContext{
      id: generate_id(),
      on_event: opts[:on_event] || (&ExecutionContext.noop/1)
    }

    {:ok, pid} = ExecutionProcess.start_link(%{agent: agent, ctx: ctx})
    ExecutionProcess.run(pid, message)
  end

  defp generate_id do
    Base.encode64(:crypto.strong_rand_bytes(16), padding: false)
  end
end
```

---

## App Implementation

### ReqLLM Adapter

```elixir
defmodule MyApp.LLM.ReqLLM do
  @type t :: %__MODULE__{model: String.t()}

  defstruct [:model]

  def new(model), do: %__MODULE__{model: model}

  def claude_haiku, do: new("anthropic:claude-haiku-4-5")
  def claude_sonnet, do: new("anthropic:claude-sonnet-4-20250514")
end

defimpl Swarm.LLM, for: MyApp.LLM.ReqLLM do
  def call(%{model: model}, messages, _opts) do
    context =
      messages
      |> Enum.map(&to_req_message/1)
      |> ReqLLM.Context.new()

    case ReqLLM.generate_text(model, context) do
      {:ok, response} ->
        {:ok, %Swarm.LLM.Response{
          content: response.content,
          usage: normalize_usage(response.usage),
          raw: response
        }}

      {:error, _} = error ->
        error
    end
  end

  defp to_req_message(%{role: "system", content: c}), do: ReqLLM.Context.system(c)
  defp to_req_message(%{role: "user", content: c}), do: ReqLLM.Context.user(c)
  defp to_req_message(%{role: "assistant", content: c}), do: ReqLLM.Context.assistant(c)

  defp normalize_usage(nil), do: nil
  defp normalize_usage(u), do: %{input_tokens: u.input, output_tokens: u.output}
end
```

### Agent

```elixir
defmodule MyApp.Agents.Greeter do
  @type t :: %__MODULE__{
    name: String.t(),
    llm: Swarm.LLM.t()
  }

  @enforce_keys [:name]
  defstruct [:name, :llm]

  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      llm: opts[:llm] || MyApp.LLM.ReqLLM.claude_haiku()
    }
  end
end

defimpl Swarm.Agent, for: MyApp.Agents.Greeter do
  def system_prompt(%{name: name}) do
    "You are a friendly assistant named #{name}. Be helpful and concise."
  end

  def llm(%{llm: llm}), do: llm
end
```

### Usage

```elixir
# Simple
agent = MyApp.Agents.Greeter.new("Claude")
{:ok, response} = Swarm.execute(agent, "Hello!")

# With event handler
agent = MyApp.Agents.Greeter.new("Claude")

{:ok, response} = Swarm.execute(agent, "Hello!",
  on_event: fn
    %Swarm.Events.StepCompleted{duration_ms: ms} ->
      IO.puts("Step took #{ms}ms")
    _ ->
      :ok
  end
)

# With different LLM
agent = MyApp.Agents.Greeter.new("Claude", llm: MyApp.LLM.ReqLLM.claude_sonnet())
{:ok, response} = Swarm.execute(agent, "Explain monads")
```

### Test Mock

```elixir
defmodule MyApp.LLM.Mock do
  defstruct [:response]

  def new(content) do
    %__MODULE__{response: %Swarm.LLM.Response{content: content}}
  end
end

defimpl Swarm.LLM, for: MyApp.LLM.Mock do
  def call(%{response: response}, _messages, _opts) do
    {:ok, response}
  end
end

# In tests
test "greeter responds" do
  agent = %MyApp.Agents.Greeter{
    name: "Test",
    llm: MyApp.LLM.Mock.new("Hello there!")
  }

  assert {:ok, "Hello there!"} = Swarm.execute(agent, "Hi")
end
```

---

## File Structure

```
lib/swarm/
├── swarm.ex                 # Entry point: Swarm.execute/3
├── agent.ex                 # Protocol
├── llm.ex                   # Protocol
├── llm/
│   └── response.ex          # Normalized response struct
├── effect.ex                # Boundary type
├── events.ex                # Event structs
├── loop.ex                  # Loop + Step structs
├── loop/
│   └── runner.ex            # Pure functions
├── execution_context.ex     # Runtime config
└── execution_process.ex     # GenServer effect interpreter

lib/my_app/
├── llm/
│   ├── req_llm.ex           # ReqLLM adapter
│   └── mock.ex              # Test mock
└── agents/
    └── greeter.ex           # Example agent
```

---

## What This Gives Us

1. **Clean separation**: Loop.Runner is pure, ExecutionProcess handles effects
2. **Pluggable LLM**: Agent owns the LLM client, can swap providers
3. **Step tracking**: Every execution has steps with timing
4. **Events**: Observable execution for logging/persistence
5. **Testable**: Mock LLM for fast, deterministic tests
6. **Foundation**: Ready to add tools, multi-step loops, child agents

---

## Next Steps (Not Now)

- Add tool execution to Effect
- Loop.Runner handles tool calls → multiple steps
- Spawn effect for child agents
- ExecutionProcess supervision tree
