module Part = Agent__Task__Message__Part
S.enableJson()

module Status = {
  @schema
  type t =
    | Submitted
    | Working
    | Completed

  let toString = (status: t): string => {
    switch status {
    | Submitted => "Submitted"
    | Working => "Working"
    | Completed => "Completed"
    }
  }
}

@schema
type id = Agent__Task__Id.t
@schema
type t = {
  id: id,
  status: Status.t,
  history: array<Agent__Task__Message.t>,
  artifacts: array<Agent__Artifact.t>,
}

module Event = {
  @schema
  type t =
    // Lifecycle events
    | Created({id: id, initialMessage: Agent__Task__Message.t})
    | ProcessingStarted({task: t})
    | Completed({task: t, message: @s.null option<Agent__Task__Message.t>})
    // Message events
    | MessageAdded({task: t, message: Agent__Task__Message.t})

  let toString: t => string = event => {
    event
    ->S.reverseConvertOrThrow(schema)
    ->JSON.stringifyAny
    ->Option.getOr("unable to stringify event")
  }
}

type cmd =
  // Lifecycle commands
  | Create({initialMessage: Agent__Task__Message.t})
  | Complete({task: t, message: option<Agent__Task__Message.t>})
  // Message commands
  | AddMessage({task: t, message: Agent__Task__Message.t})

let systemMessage = `
You are a coding assistant for a Next.js app (TypeScript, React, Tailwind, some ReScript output).
Rules
  - Paths relative to repo root.
  - List → Read → Modify. Never edit unseen files.
  - Keep diffs small and reversible. Match repo style.
  - After 2 failed tool calls, ask one clarifying question.

ReScript handling (explicit)
  - Treat generated files (*.res.mjs) as read-only.
  - Always edit the source *.res.
  - Procedure when you see X.res.mjs:
  - Locate X.res by name/path. If not found, search siblings or module index.
  - read_file both X.res and X.res.mjs to understand mapping and exports.
  - Apply changes to X.res only. Preserve types and module boundaries.
  - If no matching *.res exists or mapping is unclear, stop and ask for the exact source path.
  - Never write to generated artifacts. Note this in the output if a change seems required there.

Next.js
  - Detect router (app/pages) and stick to it.
  - "use client" only when required.
  - Keep server actions and non-serializable logic on the server.
  - TypeScript / React / Tailwind
  - Avoid any. Prefer discriminated unions.
  - Pure components and stable hooks.
  - Use Tailwind utilities and existing tokens.

Output
  - short plan
  - single unified diff block
  - brief notes: build/test results or follow-ups`

// Constructors
let make = (id, initialMessage): t => {
  let systemMsg = Agent__Task__Message.System({
    taskId: id,
    content: systemMessage,
  })

  {
    id,
    status: Status.Submitted,
    history: [systemMsg, initialMessage],
    artifacts: [],
  }
}

let decide = (state: option<t>, command: cmd): result<list<Event.t>, string> => {
  switch (state, command) {
  | (None, Create({initialMessage})) => {
      let id = Agent__Id.make()
      // NOTE(Danni) - when moving to explicit task management, we'll get the id externally for create
      let task = make(id, initialMessage)
      // Emit both Created and ProcessingStarted to immediately start processing
      Ok(list{Created({id, initialMessage}), ProcessingStarted({task: task})})
    }
  | (Some(_), Create(_)) => Error("Task already exists - cannot create again")

  | (Some({status: Working} as task), Complete({message})) => Ok(list{Completed({task, message})})

  // === Message Handling ===
  | (Some(task), AddMessage({message})) => Ok(list{MessageAdded({task, message})})

  | (None, AddMessage(_)) => Error("Cannot add message to non-existent task")

  | (Some({status}), _) => Error(`Invalid command for current status: ${Status.toString(status)}`)

  | (None, _) => Error("Cannot execute command on non-existent task")
  }
}

// Evolve: apply event to state
// PURE FUNCTION
let evolve = (state: option<t>, event: Event.t): Result.t<t, string> => {
  switch (state, event) {
  // === Creation ===
  | (None, Created({id, initialMessage})) => Ok(make(id, initialMessage))
  | (Some(_), Created(_)) => Error("cannot create an already existing event")

  // === Status Changes ===
  | (Some(task), ProcessingStarted(_)) => Ok({...task, status: Working})

  | (Some(task), Completed(_)) => Ok({...task, status: Completed})

  // === Message Handling ===
  | (Some(task), MessageAdded({message, _})) =>
    Ok({...task, history: Array.concat(task.history, [message])})

  // === Invalid ===
  | (None, _) => Error(`Tried to run event: ${event->Event.toString}`)
  }
}

// Queries
let getStatus = (task: t): Status.t => task.status
let getId = (task: t): id => task.id
let getHistory = (task: t): array<Agent__Task__Message.t> => task.history
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts
