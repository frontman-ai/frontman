# FrontmanStyle for Elixir — Coding Style Bible

Apply these principles to all Elixir code in this repo.

## Priority Order
Safety > Performance > Developer Experience. All three matter.

## Safety

- **Simple, explicit control flow only.** Prefer `case`, `cond`, and multi-clause functions over
  deeply nested `if/else`. Use `with` for railway-oriented pipelines. Avoid recursion unless it is
  the natural expression of the problem (e.g. tree traversal); when used, always have a base clause
  first and assert termination with a decreasing bound.

- **Put a limit on everything.** All `Stream` pipelines and recursive functions must have an
  explicit bound. GenServer mailboxes should have backpressure or bounded queues. Use
  `:queue.len/1` checks or `Process.info(self(), :message_queue_len)` guards where needed.
  Timeouts on every `GenServer.call`, every `Task.await`, every `Req` request. No unbounded waits.

- **Guard clauses are your assertions.** Use `when` guards liberally in function heads to assert
  pre-conditions at the boundary. They crash on violation — exactly what we want.

  ```elixir
  # Good: guard asserts the invariant, crash on violation.
  def transfer(amount, from, to) when is_integer(amount) and amount > 0 do
    ...
  end
  ```

- **Pair assertions.** For every property you enforce, find at least two code paths to check it.
  Validate at the boundary (function head guards, changeset validations) AND at the point of use
  (before writing to DB, before sending to external service).

- **Assert positive AND negative space.** Pattern match the happy path explicitly, and add a
  catch-all clause that raises or returns `{:error, reason}` — never silently drops through.

  ```elixir
  # Good: positive and negative space both covered.
  case result do
    {:ok, value} -> handle(value)
    {:error, reason} -> {:error, reason}
  end

  # Bad: silent fallthrough.
  case result do
    {:ok, value} -> handle(value)
    _ -> :ok
  end
  ```

- **All errors must be handled.** No bare `rescue` that swallows. No `catch :exit, _ -> :ok`.
  If you rescue, log and re-raise or return a tagged error. Let it crash when supervision will
  recover; handle explicitly when it won't.

- **Let it crash — but intentionally.** Crash on programmer errors (bad state, violated invariants).
  Handle operational errors (network timeouts, malformed user input) with tagged tuples. The
  supervisor tree is your safety net, not an excuse to be sloppy.

- **Smallest possible scope for variables.** Bind variables inside the narrowest `case`/`with`/`fn`
  block. Don't let bindings leak into outer scope unnecessarily. Prefer piping transformations over
  intermediate bindings.

- **Hard limit: 70 lines per function clause.** If a function body exceeds 70 lines, extract helper
  functions. Push branching logic up into the caller; keep helpers pure and branch-free.

- **All compiler warnings are errors.** Run `mix compile --warnings-as-errors`. Treat Dialyzer
  warnings the same way. Credo on strict mode.

- **Don't react directly to external events.** GenServers should process messages at their own pace.
  Use `handle_continue/2` to defer work after init. Batch where possible. Rate-limit incoming
  messages rather than processing them as fast as they arrive.

- **No compound boolean conditions.** Split into `with` or multi-clause functions or nexted `case`:

  ```elixir
  # Bad: compound condition.
  if valid?(user) and active?(account) and under_limit?(amount) do

  # Good: with clause.
  with true <- valid?(user),
       true <- active?(account),
       true <- under_limit?(amount) do
    proceed()
  else
    false -> {:error, :validation_failed}
  end

  # Also good: nested, each condition clear.
  case valid?(user) do
    true ->
      case active?(account) do
        true ->
          case under_limit?(amount) do
            true -> proceed()
            false -> {:error, :over_limit}
          end
        false -> {:error, :inactive_account}
      end
    false -> {:error, :invalid_user}
  end
  ```

- **State invariants positively.** `if index < length` not `if index >= length`. Guard with
  `when count > 0` not `when count != 0`.

## Domain Design

### Naming (Ubiquitous Language)

- **Name modules and functions in domain language, not technical language.** `Interaction.UserMessage`,
  `Model.parse/1`, not `ChatEntry`, `DataTransformer`, `MessageProcessor`. Nouns = domain concepts.
  Verbs = domain actions.

- **Types are the ubiquitous language made executable.** Structs mirror the nouns stakeholders use.
  `Model` not `ProviderModelString`. `ResolvedKey` not `ApiKeyResolutionResult`. If the product name
  changes, the type name changes.

### Contexts (Bounded Boundaries)

- **Contexts are the public API. Everything inside is private.** Other contexts and LiveViews call
  `Organizations.create_organization/2`, never `Organizations.Organization.changeset/2` directly.
  Internal schemas, query builders, and domain types are implementation details.

- **Scope carries authorization through every context boundary.** Every public context function that
  touches user data takes `%Scope{}` as first argument. Pattern match it in function heads. Never pass
  raw `user_id` across boundaries.

- **Cross-context operations get a named coordination module.** When an operation needs multiple
  contexts atomically, create a top-level module named for the business workflow (not
  `AccountsOrganizationsService`). It sequences context calls — zero domain logic inside.

### Invariants

- **Enforce invariants at the boundary, not in the middle.** Changesets validate at the persistence
  boundary. Guards validate at function heads. One place to look, one place to fix. Don't scatter the
  same check across helpers.
  - Example: `Organization.changeset/2` validates slug format once — not checked again in the context.

- **Use Ecto.Multi when the aggregate spans multiple inserts.** An organization without an owner is
  invalid → `Ecto.Multi` inserts both `Organization` and owner `Membership` atomically. Broadcast
  domain events *after* the Multi commits, never inside it.

- **Split read models from persistence schemas only when they diverge.** Start with one Ecto schema.
  Split into TypedStruct (read) + Ecto.Schema (write) when the shapes genuinely differ. Example:
  `Task` (TypedStruct with `interactions` as domain types) vs `TaskSchema` (Ecto schema with
  associations). The context bridges them via a private converter.

## Performance

- **Think about performance from the design phase.** The 1000x wins are in the architecture: batch
  vs one-at-a-time, ETS vs GenServer state, `Stream` vs eager `Enum`, single query vs N+1.

- **Back-of-envelope sketches** for network, disk, memory, CPU (bandwidth + latency). Know your
  numbers: GenServer call overhead (~5μs), ETS read (~0.5μs), Ecto query (~1ms+), HTTP call (~50ms+).

- **Optimize slowest resources first:** network > disk > memory > CPU. But compensate for
  frequency — a hot ETS lookup can matter more than a rare HTTP call.

- **Batch accesses.** Use `Repo.insert_all`, `Ecto.Multi`, bulk PubSub broadcasts. Amortize
  serialization costs. Prefer `Enum.reduce` building a result in one pass over multiple `Enum.map`
  / `Enum.filter` chains that traverse the list repeatedly.

- **Be explicit about ETS access patterns.** `:read_concurrency`, `:write_concurrency`,
  `{:decentralized_counters, true}` — set them intentionally, not by default.

- **Preload strategically.** `Repo.preload` outside the transaction. Use `join` + `preload` for
  queries that always need associations. Never preload in a loop.

## Developer Experience

- **Get the nouns and verbs just right.** `create_transfer` not `do_transfer`. `expire_session`
  not `handle_session_timeout`. Names capture what a thing IS or DOES.

- **No abbreviations.** `account_balance` not `acct_bal`. `message_count` not `msg_cnt`.
  Exception: universally understood (`id`, `db`, `url`, `pid`).

- **Units and qualifiers last, descending significance:**

  ```elixir
  # Good: groups by concept, aligns visually.
  latency_ms_max = 500
  latency_ms_min = 10
  timeout_ms = 5_000

  # Bad: buries the concept.
  max_latency_ms = 500
  min_latency_ms = 10
  ```

- **Related names should have the same character count** where feasible. `source` and `target`
  over `src` and `dest` — so `source_offset` and `target_offset` align.

- **Order matters.** Public API functions at the top of the module. Callbacks next. Private helpers
  last. Within each group, order by importance or call sequence, not alphabetically.

- **Callbacks go last in parameter lists.** Matches Elixir convention — the function/block always
  comes at the end.

- **Don't duplicate state.** No `assign(socket, user: user, user_name: user.name)`. Derive in the
  template. If you store it twice, it will drift.

- **Bind variables close to use.** No `user = Repo.get!(User, id)` at the top of a 40-line
  function if it's only used at line 35.

- **Simpler return types.** `:ok` > `{:ok, value}` > `{:error, reason}`. Don't return
  `{:ok, value, metadata}` when metadata could be derived. Minimize the dimensionality callers
  must handle.

- **Comments are sentences.** Capital letter, full stop. `# Expire sessions older than 30 days.`
  Not `# expire old sessions`. Inline comments after code can be phrases.

- **Always say WHY.** Code shows what. Comments show why. If the why is obvious, no comment needed.

- **Descriptive commit messages** that inform and delight. The commit message is permanent; the PR
  description is not.

- **Minimize dependencies.** Every dep is a supply chain risk, a version conflict waiting to happen,
  and API surface to learn. Prefer stdlib. Vet deps hard before adding.

- **Standardize tooling.** `mix` for everything. Makefiles as the universal entry point. No ad-hoc
  scripts in three different languages.

## Zero Technical Debt

- Do it right the first time. The second time may not come.
- Solve showstoppers when found, don't defer them.
- Simplicity is the hardest revision, not the first attempt.
- What we ship is solid. We may lack features, but what we have meets our design goals.

## Off-By-One Prevention

- Treat index, count, and size as conceptually distinct. Elixir is 0-indexed for lists
  (`Enum.at/2`) and for binaries (`binary_part`). Know which you're using.
- Show division intent: `div(a, b)` for truncating integer division, `rem(a, b)` for remainder.
  Use `ceil(a / b)` patterns explicitly when you need ceiling division.
- Use `Enum.chunk_every/2` over manual index arithmetic.

## Style Numbers

- 2-space indentation (Elixir convention via `mix format`).
- 98-column line limit (Elixir formatter default). Use it up. Never exceed.
- Run `mix format` on every save. Non-negotiable.
- Run `mix credo --strict`. Treat warnings as errors.
- Run Dialyzer. `@spec` on all public functions.
