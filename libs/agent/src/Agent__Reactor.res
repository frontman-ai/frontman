// Reactor - Pure event-to-command transformation
//
// Reacts to domain events by returning commands that should be executed.
// This is pure business logic with no side effects.
//
// Pattern:
// 1. Event is emitted from aggregate after evolve
// 2. Reactor receives event
// 3. Reactor returns list of commands to execute
// 4. Commands are enqueued and executed by Agent.run()

module Command = Agent__Command
module TaskMessage = Agent__Task__Message

// Pure reaction: transform event into commands based on business rules
let react = (event: Agent__EventBus.events): list<Command.t> => {
  // Console.log2("=== Reactor: added event:", event)
  switch event {
  // Task lifecycle: Created → no action needed (ProcessingStarted is emitted together)
  | TaskEvent(_, Created(_)) => {
      Agent__Logger.Log.debug("Reactor: Created event - no action needed")
      list{}
    }

  // Task lifecycle: ProcessingStarted → run first LLM iteration
  | TaskEvent(task, ProcessingStarted(_)) => {
      Agent__Logger.Log.debug("Reactor: ProcessingStarted - emitting RunIteration effect")
      list{Effect(RunLLMIteration({task: task}))}
    }

  // Assistant response with tool calls → execute tools and return results
  | TaskEvent(task, MessageAdded({message: Assistant({content: List(parts), _}) as message}))
    if parts->Array.some(part =>
      switch part {
      | ToolCall(_) => true
      | _ => false
      }
    ) => {
      Agent__Logger.Log.debug(
        "Reactor: Assistant message has tool calls - emitting ExecuteTool effect",
      )
      let toolCalls = TaskMessage.extractToolCalls(message)
      list{Effect(ExecuteTools({task, toolCalls}))}
    }

  // Assistant response without tool calls (Working status) → task is complete
  | TaskEvent({status: Working} as task, MessageAdded({message: Assistant(_) as message})) => {
      Agent__Logger.Log.debug("Reactor: Assistant message complete - finishing task")
      let cmd: Agent__Task.cmd = Complete({task, message: Some(message)})
      list{Domain({task: Some(task), cmd})}
    }

  // Assistant response without tool calls (not Working) → ignore, task already finished
  | TaskEvent({id, _}, MessageAdded({message: Assistant(_) as message})) => {
      Agent__Logger.Log.debug(
        `Reactor: MessageAdded event ${id} ${message->Agent__Task__Message.toString}`,
      )
      Agent__Logger.Log.debug("Reactor: Task not in Working status, skipping completion")
      list{}
    }

  // Tool results received → run next LLM iteration with tool results
  | TaskEvent(task, MessageAdded({message: Tool(_)})) => {
      Agent__Logger.Log.debug("Reactor: Tool message added - emitting RunIteration effect")
      list{Effect(Command.Effect.RunLLMIteration({task: task}))}
    }

  // User or System messages → no automatic reaction (handled explicitly by commands)
  | TaskEvent({id, _}, MessageAdded({message})) => {
      Agent__Logger.Log.debug(
        `Reactor: MessageAdded event ${id} ${message->Agent__Task__Message.toString}`,
      )
      list{}
    }

  // Terminal states: no further reactions needed
  | TaskEvent(_, Completed(_)) => {
      Agent__Logger.Log.debug("Reactor: Task completed")
      list{}
    }

  // Stream events: system events, no domain commands triggered
  | StreamEvent(_, _) => list{}
  }
}
