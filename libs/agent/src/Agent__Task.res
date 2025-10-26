// Task aggregate root - immutable

module Part = Agent__Task__Message__Part

module Status = {
  type t =
    | Submitted
    | Working({message: option<Agent__Task__Message.t>})
    | Completed({message: option<Agent__Task__Message.t>})

  let isTerminal = (status: t): bool => {
    switch status {
    | Completed(_) => true
    | Submitted | Working(_) => false
    }
  }

  let toString = (status: t): string => {
    switch status {
    | Submitted => "Submitted"
    | Working(_) => "Working"
    | Completed(_) => "Completed"
    }
  }
}

@schema
type id = Agent__Task__Id.t
type t = {
  id: id,
  status: Status.t,
  history: array<Agent__Task__Message.t>,
  artifacts: array<Agent__Artifact.t>,
  metadata: option<Dict.t<JSON.t>>,
}

type evt =
  // Lifecycle events
  | Created({id: id, initialMessage: Agent__Task__Message.t})
  | ProcessingStarted({task: t, message: option<Agent__Task__Message.t>})
  | Completed({task: t, message: option<Agent__Task__Message.t>})
  // Message events
  | MessageAdded({task: t, message: Agent__Task__Message.t})

type cmd =
  // Lifecycle commands
  | Create({initialMessage: Agent__Task__Message.t})
  | Complete({task: t, message: option<Agent__Task__Message.t>})
  // Message commands
  | AddMessage({task: t, message: Agent__Task__Message.t})

let systemMessage = `You are an AI coding assistant helping with a Next.js project.
  The project uses TypeScript, React, and Tailwind CSS.
  IMPORTANT Tool Usage Guidelines:
  - All file paths must be RELATIVE to the project root (e.g., 'src/components/Button.tsx', not '/full/path/...')
  - Use list_files with directory="." to see the root directory structure first
  - If a directory doesn't exist, try listing the parent directory to understand the structure
  - Read files before modifying them to understand the current code
  - After 2-3 failed tool calls, stop and ask the user for clarification
  When making changes, ensure they are compatible with the Next.js framework and follow React best practices.`

// Constructors
let make = (id, initialMessage): t => {
  let systemMsg = Agent__Task__Message.System({
    taskId: Some(id),
    content: systemMessage,
  })

  {
    id,
    status: Status.Submitted,
    history: [systemMsg, initialMessage],
    artifacts: [],
    metadata: None,
  }
}

// Decide: validate command against current state and produce events
// PURE FUNCTION
let decide = (state: option<t>, command: cmd): result<list<evt>, string> => {
  switch (state, command) {
  | (None, Create({initialMessage})) => {
      let id = Agent__Id.make()
      let task = make(id, initialMessage)
      // Emit both Created and ProcessingStarted to immediately start processing
      Ok(list{Created({id, initialMessage}), ProcessingStarted({task, message: None})})
    }
  | (Some(_), Create(_)) => Error("Task already exists - cannot create again")

  | (Some({status: Working(_), _} as task), Complete({message})) =>
    Ok(list{Completed({task, message})})

  // === Message Handling ===
  | (Some(task), AddMessage({message})) => Ok(list{MessageAdded({task, message})})

  | (None, AddMessage(_)) => Error("Cannot add message to non-existent task")

  // === Invalid Transitions ===
  | (Some({status: Completed(_), _}), _) => Error("Cannot modify completed task")

  | (Some({status, _}), _) =>
    Error(`Invalid command for current status: ${Status.toString(status)}`)

  | (None, _) => Error("Cannot execute command on non-existent task")
  }
}

// Evolve: apply event to state
// PURE FUNCTION
let evolve = (state: option<t>, event: evt): option<t> => {
  switch (state, event) {
  // === Creation ===
  | (None, Created({id, initialMessage})) => Some(make(id, initialMessage))
  | (Some(_), Created(_)) => %todo("cannot reach this case")

  // === Status Changes ===
  | (Some(task), ProcessingStarted({message})) =>
    Some({...task, status: Working({message: message})})

  | (Some(task), Completed({message})) => Some({...task, status: Completed({message: message})})

  // === Message Handling ===
  | (Some(task), MessageAdded({message, _})) =>
    Some({...task, history: Array.concat(task.history, [message])})

  // === Invalid ===
  | (None, _) => None
  }
}

// Queries
let isTerminal = (task: t): bool => Status.isTerminal(task.status)
let getStatus = (task: t): Status.t => task.status
let getId = (task: t): id => task.id
let getHistory = (task: t): array<Agent__Task__Message.t> => task.history
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts
