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
let react = (task: Agent__Task.t, event: Agent__EventBus.events): list<Command.t> => {
  switch event {
  | TaskEvent(_, Created(_)) => {
      Agent__Logger.Log.debug("Reactor: Created event - no action needed")
      list{}
    }

  | TaskEvent(_, ProcessingStarted(_)) => {
      Agent__Logger.Log.debug("Reactor: ProcessingStarted - emitting RunIteration effect")
      list{Effect(RunLLMIteration({task: task}))}
    }

  | TaskEvent(_, MessageAdded({message: Assistant({content: List(parts), _}) as message}))
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
  | TaskEvent(_, MessageAdded({message: Assistant(_) as message})) if task.status == Working => {
      Agent__Logger.Log.debug("Reactor: Assistant message complete - finishing task")
      let cmd: Agent__Task.cmd = Complete({task, message: Some(message)})
      list{Domain({task: Some(task), cmd})}
    }

  // Assistant response without tool calls (not Working) → ignore, task already finished
  | TaskEvent(id, MessageAdded({message: Assistant(_) as message})) => {
      Agent__Logger.Log.debug(
        `Reactor: MessageAdded event ${id} ${message->Agent__Task__Message.toString}`,
      )
      Agent__Logger.Log.debug("Reactor: Task not in Working status, skipping completion")
      list{}
    }

  // Tool results received → run next LLM iteration with tool results
  | TaskEvent(_, MessageAdded({message: Tool(_)})) => {
      Agent__Logger.Log.debug("Reactor: Tool message added - emitting RunIteration effect")
      list{Effect(Command.Effect.RunLLMIteration({task: task}))}
    }

  // User message on Completed task → resume the task
  | TaskEvent(_, MessageAdded({message: TaskMessage.User(_)})) if task.status == Completed => {
      Agent__Logger.Log.debug("Reactor: User message on completed task - resuming")
      let cmd: Agent__Task.cmd = Resume({task: task})
      list{Domain({task: Some(task), cmd})}
    }

  // User or System messages on other statuses → no automatic reaction (handled explicitly by commands)
  | TaskEvent(id, MessageAdded({message})) => {
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
