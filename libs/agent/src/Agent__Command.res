// Unified Command Type
// Commands are instructions to change system state (Domain) or perform side effects (Effect)

// Domain commands operate on aggregates via decide/evolve
module Domain = {
  type t = {
    task: option<Agent__Task.t>,
    cmd: Agent__Task.cmd,
  }
}

// Effect commands describe async operations at the system edge
module Effect = {
  type t =
    | RunLLMIteration({task: Agent__Task.t})
    | ExecuteTools({
        task: Agent__Task.t,
        toolCalls: array<Agent__Task__Message__Part.ToolCallPart.t>,
      })
}

type t =
  | Domain(Domain.t)
  | Effect(Effect.t)

let getTask = command => {
  switch command {
  | Domain({task}) => task
  | Effect(RunLLMIteration({task})) => Some(task)
  | Effect(ExecuteTools({task})) => Some(task)
  }
}
