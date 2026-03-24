# ReScript Patterns for Frontman

## Design Goals

Safety, performance, and developer experience. In that order. All three matter. Good style advances
these goals. Does this code make for more or less safety, performance, or developer experience?
That is the question we ask of every line.

## Core Principles

### Safety First

- **Crash early and obviously.** Use `Option.getOrThrow`, `Result.getOrThrow` when a value must
  exist. A crash surfaces bugs faster than a silent fallback. Never use `Option.getOr(default)` to
  paper over unexpected states.

- **Never use `Obj.magic`** unless you have explicit permission from the user. It erases the type
  system — the primary safety net in ReScript. Every `Obj.magic` is a hole in the hull.

- **Never use mutable.** Use `ref` when mutation is truly needed. Immutable data is easier to reason
  about and eliminates an entire class of bugs where state gets out of sync.

- **Use Result types for operations that can fail.** `Ok(result)` or `Error(reason)` — make
  failure explicit in the type signature. The caller must handle both paths.

- **Prefer `switch` over `if/else`.** Pattern matching forces exhaustive handling of all cases. The
  compiler will tell you when you miss one. An `if/else` silently falls through.

  ```rescript
  // GOOD — compiler enforces exhaustive handling.
  switch status {
  | Pending => showSpinner()
  | Completed(data) => showData(data)
  | Error(msg) => showError(msg)
  }

  // BAD — what happens when a new status variant is added? Silent fallthrough.
  if status == Pending {
    showSpinner()
  } else {
    showData(data)
  }
  ```

- **All errors must be handled.** Do not use catch-all patterns (`| _ =>`) that swallow unknown
  cases. Catch-alls hide bugs by silently accepting states you did not anticipate. When the domain
  changes, the compiler cannot warn you about the new case.

### Zero Technical Debt

We do it right the first time. We may lack features, but what we have meets our design goals. This
is the only way to make steady incremental progress, knowing that the progress we have made is
indeed progress.

### Explicit Over Implicit

- **Always say why.** Comments explain rationale, not what the code does. If you explain the
  reasoning behind a decision, it shares criteria with the reader to evaluate that decision.

- **Put a limit on everything.** All loops, all queues, all retries — bounded. Unbounded iteration
  is a liveness bug waiting to happen.

- **Declare variables at the smallest possible scope.** Minimize the number of bindings in play to
  reduce the probability that the wrong one is used. Calculate or check values close to where they
  are used — do not introduce them before they are needed.

## Domain-Driven Design

Organize code around business domains, not technical layers. The module structure should mirror how
the business thinks about the problem, not how React or the framework thinks about rendering. Why:
when a product requirement changes, the change should be localized to the domain it belongs to — not
scattered across "components/", "hooks/", "utils/", "types/".

### Boundaries Are Modules

Each domain gets a module boundary — a file (or set of files sharing a namespace prefix) that
exposes a public API and hides implementation details. The boundary is where you validate, where you
annotate types, and where you say no.

```rescript
// Client__Chat.res — the public API for the Chat domain.
// Everything the rest of the app needs goes through here.
// Internal modules (Client__Chat__MessageList, Client__Chat__InputBox) are implementation details.

let sendMessage: (~content: string, ~taskId: TaskId.t) => unit
let useMessages: (~taskId: TaskId.t) => array<Message.t>
```

Why a public API module: it forces you to think about what the domain exposes. If a component deep
inside the Chat domain needs to talk to the Settings domain, it goes through `Client__Settings` —
not by importing `Client__Settings__ApiKeyForm` directly. Direct cross-domain imports create
invisible coupling that makes both domains harder to change.

### Types Live In The Domain They Describe

A `Message.t` type belongs in the Chat domain, not in a global `Client__Types.res` grab-bag. Shared
types that genuinely span domains (e.g., `TaskId.t`, `UserId.t`) get their own focused modules.
Why: a global types file becomes a dependency of everything and a bottleneck for every change.

```rescript
// GOOD — type lives where it belongs.
// Client__Chat__Message.res
@schema
type t = {
  id: string,
  content: string,
  role: role,
  timestamp: float,
}

// BAD — dumping ground that everything depends on.
// Client__Types.res
type chatMessage = { ... }
type task = { ... }
type settings = { ... }
type apiKey = { ... }
```

### Variant Types Model The Domain

Use variants to make illegal states unrepresentable. The domain dictates the variants, not the UI.
If the business says a message can be pending, sent, or failed — that is exactly three variants, not
a string, not a boolean `isSent` with a separate `error` field.

```rescript
type sendStatus =
  | Pending
  | Sent({at: float})
  | Failed({reason: string, retryable: bool})
```

Why not a record with optional fields: a record `{sent: option<float>, error: option<string>}` lets
you represent `{sent: Some(1.0), error: Some("oops")}` — a state that cannot exist in reality. The
variant makes that impossible at compile time.

### Side Effects At The Boundary

Domain logic is pure. It takes data in, returns data out. Side effects — API calls, subscriptions,
local storage — live at the boundary, in effect handlers (the StateReducer), not inside domain
modules. Why: pure functions are trivial to test, trivial to reason about, and trivial to compose.
A domain function that fires a network request is none of these things.

```rescript
// GOOD — pure domain logic. No side effects. Easy to test.
let shouldRetry = (status: sendStatus): bool => {
  switch status {
  | Failed({retryable: true}) => true
  | Pending | Sent(_) | Failed({retryable: false}) => false
  }
}

// BAD — domain logic entangled with side effects.
let retrySend = async (message: message): result<unit, string> => {
  let response = await Fetch.fetch("/api/send", ...)  // Side effect buried in domain.
  ...
}
```

### Naming Reflects The Domain

Get the nouns and verbs right. Names should come from the business domain, not from framework
jargon. If the product calls it a "conversation", don't call it a "thread" in the code. If users
"send" messages, the function is `sendMessage`, not `submitPayload`. When the domain language and
the code language match, conversations between engineers and product people become less lossy.

## File Structure

- Components: `Client__ComponentName.res` — flat folder with double-underscore namespacing.
- Domain types: `Client__DomainName__TypeName.res` — types co-located with their domain.
- Shared types: `Client__TaskId.res`, `Client__UserId.res` — small, focused, cross-domain types.
- Domain API: `Client__DomainName.res` — the public surface for a domain boundary.
- Main export: `Client.res` — the top-level public API.

Why flat folders: nested directories hide files behind clicks. The double-underscore convention gives
you namespacing without nesting, and every file is one `Cmd+P` away.

## React Components

- Use `@react.component` for all React components. Not `@genType` — that is for cross-language FFI,
  not component declaration.

- **Labelled arguments make call sites readable.** `~paramName` for required, `~paramName=?` for
  optional. The compiler enforces that callers provide required arguments — this is a safety net.

- **Let ReScript infer types.** Only add explicit annotations when the compiler requires them or
  when the annotation communicates intent that inference cannot (e.g., constraining a polymorphic
  type at a module boundary). Redundant annotations are noise — they drift from reality and give
  false confidence.

- JSX v4 style for inline styles — record syntax with unquoted keys:
  `{padding: "20px", color: "white"}`.

## Event Handling

Property access and method calls follow different pipe conventions. Getting this wrong causes
runtime errors that the compiler cannot catch because event types are structurally typed.

```rescript
// Property access: pipe TO the accessor.
e->ReactEvent.Keyboard.shiftKey

// Method call: pass the event AS the argument.
ReactEvent.Keyboard.preventDefault(e)

// Negation of a piped property: wrap in parens to bind correctly.
!(e->ReactEvent.Keyboard.shiftKey)

// Form target values: dict-style access. ##value is the old BuckleScript syntax.
target["value"]
```

## JSX Patterns

- **Text content must be wrapped.** `React.string("text")` — raw strings in JSX are a type error.

- **Conditional rendering.** Use the ternary for simple conditions:
  `condition ? <Component /> : React.null`.

- **Optional props.** Use `Option.mapOr` to handle the none case explicitly:
  `value->Option.mapOr(React.null, v => <Component value={v} />)`.
  Why `mapOr` over `map`: it forces you to handle the absence case at the call site rather than
  silently rendering nothing.

- **Unused parameters.** Prefix with `_` to suppress compiler warnings:
  `~_onClearSelection=?`. The underscore signals intent — this parameter exists for API
  compatibility but is deliberately unused here.

## Type System

- **Variant types for domain modeling.** Variants make illegal states unrepresentable:
  ```rescript
  type status = | Pending | Completed | Error(string)
  ```

- **Module-qualified access for types from other modules.** Use `Client__Types.Status` — never
  `open` a types module at file scope. Why: `open` pollutes the namespace and makes it ambiguous
  where a type comes from. Qualified access is explicit.

- **Add explicit type annotations at module boundaries.** Internal bindings: let inference work.
  Public function signatures: annotate. This is where the contract lives.
  ```rescript
  // Module boundary — annotate to document the contract.
  let make: (~messages: array<Client__Types.chatMessage>, ~onSend: string => unit) => React.element

  // Internal binding — let inference do its job.
  let filtered = messages->Array.filter(m => m.visible)
  ```

## String and Array Operations (ReScript v12+)

Use the Core standard library. Belt and Js.* are the old API — they work but fragment the codebase
with two ways to do the same thing.

| Operation | Use | Not |
|---|---|---|
| String concat | `"Hello " ++ name` | `Js.String.concat` |
| Interpolation | `` `Hello ${name}` `` | `++` chains |
| Unicode | `` `\u{1F3AF} Click` `` | `Js.String.fromCharCode` |
| Array map | `Array.mapWithIndex` | `Belt.Array.mapWithIndex` |
| Array slice | `Array.slice(~start=0, ~end=3)` | `Js.Array.slice` |
| Option unwrap | `Option.getOr` | `Belt.Option.getWithDefault` |
| Option map | `Option.mapOr` | `Belt.Option.mapWithDefault` |
| String ops | `String.length`, `String.trim` | `Js.String.length` |

Why one standard library matters: two paths to the same result means two things to remember, two
things to grep for, and two things that might subtly differ in edge-case behavior.

## React Hooks and Props

### useState

```rescript
let (value, setValue) = React.useState(() => initialValue)
```

The thunk `() => initialValue` is required. Passing `initialValue` directly is a type error.

### useEffect

Modern ReScript uses a single `React.useEffect` — the numbered variants (`useEffect1`,
`useEffect2`, etc.) are deprecated.

```rescript
// No dependencies — runs on every render. Use sparingly; this is usually wrong.
React.useEffect(() => { ... None })

// Empty deps — runs once on mount.
React.useEffect(() => { ... None }, [])

// Single dep — runs when dep changes.
React.useEffect(() => { ... None }, [dep])

// Multiple deps — use a TUPLE, not an array. This is a ReScript-specific footgun.
React.useEffect(() => { ... None }, (dep1, dep2))
```

Return type is `option<unit => unit>`:
- `None` — no cleanup needed.
- `Some(() => cleanup())` — cleanup runs before re-execution and on unmount.

### Passing Optional Props Between Components

```rescript
// Parent declares the optional prop with =? (caller may omit it).
@react.component
let make = (~onReload: option<unit => unit>=?) => {
  // Pass the option directly to the child. Do not unwrap.
  <Child onReload={onReload} />
}

// Child receives it as a plain option (no =?). The child always gets the value;
// the optionality was resolved at the parent boundary.
@react.component
let make = (~onReload: option<unit => unit>) => {
  switch onReload {
  | Some(reload) => <button onClick={_ => reload()}> {React.string("Reload")} </button>
  | None => React.null
  }
}
```

Why not unwrap at the parent: you lose the `None` information. The child needs to know whether the
callback was provided to decide what to render.

### Optional Style Props

```rescript
style={style->Option.getOr({})}
```

`getOr` here is acceptable — an empty style object is the correct default, not a masked bug.
