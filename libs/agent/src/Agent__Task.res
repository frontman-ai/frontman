// Task aggregate root - immutable

module Part = Agent__Task__Message__Part

module Status = {
  type t =
    | Submitted
    | Working({message: option<Agent__Task__Message.t>})
    | InputRequired({message: Agent__Task__Message.t})
    | Completed({message: option<Agent__Task__Message.t>})
    | Failed({message: Agent__Task__Message.t})
    | Rejected({message: Agent__Task__Message.t})
    | Canceled({message: option<Agent__Task__Message.t>})

  let isTerminal = (status: t): bool => {
    switch status {
    | Completed(_) | Failed(_) | Rejected(_) | Canceled(_) => true
    | Submitted | Working(_) | InputRequired(_) => false
    }
  }

  let toString = (status: t): string => {
    switch status {
    | Submitted => "Submitted"
    | Working(_) => "Working"
    | InputRequired(_) => "InputRequired"
    | Completed(_) => "Completed"
    | Failed(_) => "Failed"
    | Rejected(_) => "Rejected"
    | Canceled(_) => "Canceled"
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
  | Failed({task: t, error: Agent__Task__Message.t})
  | Canceled({task: t, reason: option<Agent__Task__Message.t>})
  // Message events
  | MessageAdded({task: t, message: Agent__Task__Message.t})
  // Status events
  | InputRequested({task: t, question: Agent__Task__Message.t})
  | Resumed({task: t, message: option<Agent__Task__Message.t>})
  | Rejected({task: t, reason: Agent__Task__Message.t})
  // Artifact events
  | ArtifactAdded({task: t, artifact: Agent__Artifact.t})

type cmd =
  // Lifecycle commands
  | Create({initialMessage: Agent__Task__Message.t})
  | StartProcessing({task: t, message: option<Agent__Task__Message.t>})
  | Complete({task: t, message: option<Agent__Task__Message.t>})
  | Fail({task: t, error: Agent__Task__Message.t})
  | Cancel({task: t, reason: option<Agent__Task__Message.t>})
  // Message commands
  | AddMessage({task: t, message: Agent__Task__Message.t})
  // Artifact commands
  | AddArtifact({task: t, artifact: Agent__Artifact.t})
  // Status commands
  | RequestInput({task: t, question: Agent__Task__Message.t})
  | Resume({task: t, message: option<Agent__Task__Message.t>})
  | Reject({task: t, reason: Agent__Task__Message.t})

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
    id: Agent__Id.make(),
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
      Ok(list{Created({id, initialMessage})})
    }
  | (Some(_), Create(_)) => Error("Task already exists - cannot create again")
  | (Some({status: Submitted, _} as task), StartProcessing({message})) =>
    Ok(list{ProcessingStarted({task, message})})

  | (Some({status: Working(_), _} as task), Complete({message})) =>
    Ok(list{Completed({task, message})})

  | (Some({status: Working(_), _} as task), RequestInput({question})) =>
    Ok(list{InputRequested({task, question})})

  | (Some({status: InputRequired(_), _} as task), Resume({message})) =>
    Ok(list{Resumed({task, message})})

  | (Some({status: Submitted, _} as task), Reject({reason})) => Ok(list{Rejected({task, reason})})

  | (Some({status, _} as task), Fail({error})) =>
    if Status.isTerminal(status) {
      Error("Cannot fail - task already in terminal state")
    } else {
      Ok(list{Failed({task, error})})
    }

  | (Some({status, _} as task), Cancel({reason})) =>
    if Status.isTerminal(status) {
      Error("Cannot cancel - task already in terminal state")
    } else {
      Ok(list{Canceled({task, reason})})
    }

  // === Message Handling ===
  | (Some({status, _} as task), AddMessage({message})) =>
    // Business rule: if task is InputRequired, also resume it
    switch status {
    | InputRequired(_) =>
      // Emit BOTH events: message added AND status changed
      Ok(list{MessageAdded({task, message}), Resumed({task, message: Some(message)})})
    | _ => Ok(list{MessageAdded({task, message})})
    }

  | (None, AddMessage(_)) => Error("Cannot add message to non-existent task")

  // === Artifact Handling ===
  | (Some(task), AddArtifact({artifact})) => Ok(list{ArtifactAdded({task, artifact})})

  | (None, AddArtifact(_)) => Error("Cannot add artifact to non-existent task")

  // === Invalid Transitions ===
  | (Some({status: Completed(_), _}), _) => Error("Cannot modify completed task")
  | (Some({status: Failed(_), _}), _) => Error("Cannot modify failed task")
  | (Some({status: Canceled(_), _}), _) => Error("Cannot modify canceled task")
  | (Some({status: Rejected(_), _}), _) => Error("Cannot modify rejected task")

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

  | (Some(task), Failed({error})) => Some({...task, status: Failed({message: error})})

  | (Some(task), Canceled({reason})) => Some({...task, status: Canceled({message: reason})})

  | (Some(task), InputRequested({question})) =>
    Some({...task, status: InputRequired({message: question})})

  | (Some(task), Resumed({message})) => Some({...task, status: Working({message: message})})

  | (Some(task), Rejected({reason})) => Some({...task, status: Rejected({message: reason})})

  // === Message Handling ===
  | (Some(task), MessageAdded({message, _})) =>
    Some({...task, history: Array.concat(task.history, [message])})

  // === Artifact Handling ===
  | (Some(task), ArtifactAdded({artifact, _})) =>
    Some({...task, artifacts: Array.concat(task.artifacts, [artifact])})

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
