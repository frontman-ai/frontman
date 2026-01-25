# Swarm v2 Architecture

An opinionated, event-driven agent orchestration framework built on the BEAM.

## Core Mental Model

**An agent is an Actor** (Hewitt, 1973) — an independent unit of computation that:
- Has private state (conversation history, loop state)
- Communicates via message passing
- Can spawn other actors
- Processes one message at a time

This maps directly to Erlang/OTP processes, giving us fault isolation, location transparency, and the BEAM's preemptive scheduler for free.

---

## Agent Definition

```elixir
defmodule MyAgent do
  use Swarm.Agent

  name "..."
  system_prompt "..."

  # What it can do (tools and agents, unified)
  capabilities [...]

  # What it emits (schemas as contracts)
  emits :event_name, %{field: :type}

  # What it receives
  query :name
  command :name, prompt: "..."
  interrupt :name
end
```

---

## Pattern 1: CQRS (Command Query Responsibility Segregation)

Incoming events split into three categories:

| Type | Behavior | Analogy |
|------|----------|---------|
| **Query** | Fork clone, read-only, immediate | Read replica |
| **Command** | Queued, mutates state, at loop boundary | Write to primary |
| **Interrupt** | Immediate, mechanical, cancels work | Hardware interrupt |

Queries scale without blocking the write path. Commands are ordered. Interrupts bypass the queue.

### Query

- Read-only questions about agent state or reasoning
- Handled by forking a clone of the agent
- Main agent continues uninterrupted
- Clone responds and terminates
- Examples: status checks, progress reports, explain current approach

### Command

- Mutations or new information that affect agent behavior
- Queued and processed at loop boundaries (between LLM calls)
- Customizable presentation per agent with sane defaults
- Examples: add context, reprioritize, change scope

### Interrupt

- Immediate mechanical actions that cannot wait
- Cancels current tool execution if needed
- No LLM involvement by default (optional escape hatch with timeout)
- Examples: abort, pause

```elixir
# Mechanical interrupt (default)
interrupt :abort

# Interrupt with LLM response (escape hatch)
interrupt :abort_graceful, allow_response: true, timeout_ms: 5_000
```

---

## Pattern 2: Fork-on-Read (Copy-on-Write variant)

For queries, clone the agent's context and handle in a separate process:

```
┌─────────────┐         ┌─────────────┐
│ Main Agent  │──fork──▶│   Clone     │
│ (continues) │         │ (handles    │
│             │         │  query,     │
│             │         │  terminates)│
└─────────────┘         └─────────────┘
```

Analogous to:
- **Unix fork()** — child gets copy of memory
- **Database read replicas** — reads don't block writes
- **MVCC** — readers see snapshot, writers proceed

This ensures status requests and other queries are fast regardless of what the main agent is doing.

---

## Pattern 3: Event-Carried State Transfer

Agents communicate via typed events with schemas:

```elixir
emits :task_completed, %{result: :string, metadata: :map}
emits :blocked, %{reason: :string, attempted: [:string]}
```

**Event-Carried State Transfer** (Fowler) — events carry sufficient data, receivers don't need to call back.

Events are implemented as tools the LLM can call. When the LLM calls `emit_task_completed(...)`, an event is fired. The schema acts as a contract for both:
- The LLM (via tool definition in the prompt)
- The receiving agent (can pattern match on known shapes)

---

## Pattern 4: Pub/Sub with Subscription Filtering

Parents subscribe to child events with two modes:

```elixir
subscribe ChildAgent do
  notify: [:completed, :failed]     # Push — inject into conversation
  observe: [:progress, :status]     # Pull — query when needed
end
```

Maps to **topic-based pub/sub** with filtering:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `notify` | Pushed into agent's conversation immediately | Results, failures, blocking issues |
| `observe` | Accumulated silently, queryable on demand | Progress updates, verbose status |

This prevents context pollution while ensuring important events are never missed.

---

## Pattern 5: Barrier Synchronization (Fork-Join)

When an agent spawns multiple children and waits for all:

```elixir
spawn_agent(AgentType, task_1)
spawn_agent(AgentType, task_2)
spawn_agent(AgentType, task_3)
# Framework tracks: 0/3 → 1/3 → 2/3 → 3/3 → "batch complete"
```

**Fork-Join pattern** (Doug Lea) / **Barrier synchronization**:
- Fork: spawn N parallel tasks
- Join: wait for all N to complete
- Proceed: continue with aggregated results

The framework tracks batch completion automatically. When all spawned agents in a batch complete, the parent is notified with aggregated results.

Similar to `Task.await_many/1`, `Promise.all()`, MapReduce shuffle.

---

## Pattern 6: Saga / Process Manager

Coordinating agents implement long-running workflows:

```
Request → Explore → Plan → Execute → Verify → Complete
```

**Saga pattern** (Garcia-Molina, 1987):
- Long-running process spanning multiple participants
- Coordinator tracks progress
- Handles compensating actions on failure (abort, retry with different approach)

The agent's conversation history acts as the **saga log** — it remembers what's been done and can make judgment calls about how to proceed or recover.

The LLM decides how to handle changes mid-workflow:
- Restart from scratch?
- Adjust and continue?
- Abort and report?

---

## Pattern 7: Uniform Capability Interface

Tools and child agents are unified under a single concept:

```elixir
capabilities [ReadFile, WriteFile, AnalyzerAgent, ValidatorAgent]
```

**Uniform Interface** principle / **Command pattern**:
- Everything invoked the same way
- Framework handles sync vs async, function vs actor
- Caller is agnostic to implementation details

From the LLM's perspective, calling a tool or spawning an agent looks identical:

```elixir
# LLM doesn't know (or care) if this is a function or an agent
tool_call: analyze(%{target: "src/api"})
```

The framework knows `AnalyzerAgent` is an agent and handles spawning, subscriptions, and event routing transparently.

Like Unix (everything is a file) or HTTP (everything is a resource).

---

## Pattern 8: Functional Core / Imperative Shell

```
┌─────────────────────────────────────┐
│         Imperative Shell            │
│  (executes effects, I/O, spawning)  │
├─────────────────────────────────────┤
│         Functional Core             │
│  (pure state transitions)           │
│  (effects as data structures)       │
└─────────────────────────────────────┘
```

**Ports and Adapters** / **Hexagonal Architecture** (Cockburn):
- Core is pure, testable, deterministic
- Shell handles side effects
- Effects as data = **Free Monad** pattern

The Loop and Runner remain pure functional — they produce effects as data structures. The Swarm module (shell) interprets and executes those effects.

---

## Architecture Overview

```
                         ┌───────────┐
                         │  External │
                         │  Input    │
                         └─────┬─────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Coordinator Agent  │
                    │  (Process Manager)  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │   Agent A   │      │   Agent B   │      │   Agent C   │
   │   (Actor)   │      │   (Actor)   │      │   (Actor)   │
   └──────┬──────┘      └──────┬──────┘      └─────────────┘
          │                    │
          ▼                    ▼
   ┌─────────────┐      ┌─────────────┐
   │  Agent A.1  │      │  Agent B.1  │
   └─────────────┘      └─────────────┘
```

### Communication Types

| Symbol | Type | Description |
|--------|------|-------------|
| `───▶` | Spawn | Capability invocation (tool or agent) |
| `◀───` | Notify | Events pushed to parent conversation |
| `◀┄┄┄` | Observe | Events accumulated, pulled on demand |
| `━━━▶` | Command | Queued, processed at loop boundary |
| `════▶` | Interrupt | Immediate, mechanical |
| `⇠···` | Query | Fork-on-read, ephemeral |

---

## Event Flow Through Agentic Loop

```
┌─────────────────────────────────────────────────────────────┐
│                      AGENTIC LOOP                           │
│                                                             │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │   LLM   │───▶│  Tool   │───▶│ Results │───▶│   LLM   │  │
│  │  Call   │    │  Exec   │    │  Back   │    │  Call   │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
│       │              │              │              │        │
│       │              │              ▼              │        │
│       │              │     ┌───────────────┐      │        │
│       │              │     │ COMMAND QUEUE │      │        │
│       │              │     │   processed   │      │        │
│       │              │     │     here      │      │        │
│       │              │     └───────────────┘      │        │
│       │              │                            │        │
└───────┼──────────────┼────────────────────────────┼────────┘
        │              │                            │
   ┌────┴────┐    ┌────┴────┐                  ┌────┴────┐
   │ QUERIES │    │INTERRUPT│                  │ QUERIES │
   │ (fork)  │    │ (cancel)│                  │ (fork)  │
   └─────────┘    └─────────┘                  └─────────┘
```

### Injection Points

- **Queries**: Can happen anytime (forked, don't affect main loop)
- **Interrupts**: Can happen anytime (cancel current work)
- **Commands**: Processed between tool results and next LLM call
- **Child events (notify)**: Injected at loop boundaries like commands

---

## Design Principles

### 1. Explicit Over Implicit

- Events have schemas (contracts)
- Subscriptions declare what to notify vs observe
- Commands specify their presentation per agent

### 2. LLM Decides, Framework Enables

The framework provides capabilities (query, command, interrupt, spawn). The LLM makes judgment calls:
- Should I restart or adjust?
- Which agents do I need?
- How do I handle this failure?

### 3. Agents Externalize Thinking

If it's not in an event or state, it doesn't exist. Agents should emit findings, progress, and decisions — not hold them in context to be lost on abort.

### 4. Fail Fast, Recover Smart

- Interrupts are mechanical and immediate
- The LLM handles recovery logic
- Conversation history serves as the saga log for recovery decisions

---

## Open Questions

| Question | Relevant Patterns |
|----------|-------------------|
| Event persistence for replay/debugging? | Event Sourcing, Event Store |
| Fault tolerance structure? | OTP Supervision Trees |
| Flow control when events outpace processing? | Backpressure, Bounded Queues |
| Agents across nodes? | Location Transparency, Distribution |
| Conversation history growth? | Compaction, Summarization, Windowing |
| Tool cancellation protocol? | Cooperative cancellation, Timeouts |
