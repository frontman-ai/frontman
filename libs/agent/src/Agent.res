// Main Agent module - entry point
S.enableJson()

module Bindings = AskTheLlmBindings

module Tools = {
  module Registry = Agent__ToolsRegistry
}
module Adapters = {
  module Vercel = Agent__Adapters__Vercel
}
module StreamProcessor = Agent__StreamProcessor
module AgenticLoop = Agent__AgenticLoop
module Task = Agent__Task
module TaskMessage = Agent__Task__Message
module Part = Agent__Task__Message__Part
module Artifact = Agent__Artifact
module Id = Agent__Id
module TaskId = Agent__Task__Id
module EventBus = Agent__EventBus
module TaskCommands = Agent__Task__Commands
module TaskEvents = Agent__Task__Events

type t = {
  projectRoot: string,
  eventBus: EventBus.t,
  tasks: Agent__Tasks.t,
  llm: Adapters.Vercel.t,
  config: Agent__Config.t,
  toolRegistry: Agent__ToolsRegistry.t,
}
type config = Agent__Config.t

let make = (config: config) => {
  Console.log(`Initializing agent for project: ${config.projectRoot}`)
  let eventBus = EventBus.make()

  let model = Agent__Bindings__Vercel.OpenAI.gpt4o(config.apiKey)

  let toolRegistry = Agent__ToolsRegistry.make()
  let llm = Agent__Adapters__Vercel.makeLLM(~model, ~toolRegistry)

  Console.log(`Agent initialized with ${toolRegistry->Array.length->Int.toString} tools`)

  {
    projectRoot: config.projectRoot,
    eventBus,
    tasks: Agent__Tasks.make(),
    llm,
    config,
    toolRegistry,
  }
}

// Execute a task command using Command → Decide → Events → Evolve
let executeTaskCommand = (agent: t, taskId: Agent__Task__Id.t, cmd: TaskCommands.t): result<
  Agent__Task.t,
  string,
> => {
  let currentTask = Agent__Tasks.get(agent.tasks, taskId)

  Agent__Task.decide(currentTask, cmd)->Result.map(events => {
    let newTask = events->List.reduce(currentTask, Agent__Task.evolve)

    switch newTask {
    | Some(task) => {
        Agent__Tasks.update(agent.tasks, task)

        // Emit domain events on EventBus wrapped with aggregate state
        events->List.forEach(event => {
          agent.eventBus->EventBus.emit(TaskEvent(task, event))
        })

        task
      }
    | None =>
      JsError.throwWithMessage("Internal error: evolve returned None after decide succeeded")
    }
  })
}

let run = (agent: t) => {
  Console.log("Agent is running and listening for domain events...")
  let unsubscribe = agent.eventBus->EventBus.on(event => {
    Console.log2("Got EventBus Event: ", event)
    switch event {
    | TaskEvent(task, Created(_)) => {
        Console.log("=== Created event - transitioning to Working")
        // Transition task to Working - will emit ProcessingStarted event
        let _ = executeTaskCommand(agent, task.id, TaskCommands.StartProcessing({message: None}))
      }
    | TaskEvent(task, ProcessingStarted(_)) => {
        Console.log("=== ProcessingStarted event - starting iteration")
        // Start first iteration
        Agent__AgenticLoop.runIteration(
          agent.llm,
          (taskId, cmd) => executeTaskCommand(agent, taskId, cmd),
          task,
        )->ignore
      }
    | TaskEvent(task, MessageAdded({message})) => {
        Console.log3("=== MessageAdded event", task.id, message)

        // Check if message has tool calls
        if message->Agent__Task__Message.hasToolCalls {
          Console.log("=== Assistant message has tool calls - executing tools")

          // Execute tools as async side effect
          (
            async () => {
              try {
                // Extract tool calls and execute them
                let toolCalls = Agent__ToolExecutor.extractToolCalls(message)
                Console.log(`=== Executing ${toolCalls->Array.length->Int.toString} tool calls`)

                let toolMessage = await Agent__ToolExecutor.executeToolCalls(
                  agent.config,
                  agent.toolRegistry,
                  task.id,
                  toolCalls,
                )

                Console.log2("=== Tool execution complete, results:", toolMessage)

                // Add tool message to task history via command
                let _ = executeTaskCommand(
                  agent,
                  task.id,
                  TaskCommands.AddMessage({message: toolMessage}),
                )
              } catch {
              | exn => Console.error2("=== Tool execution failed with exception:", exn)
                // TODO: Implement proper error handling
              }
            }
          )()->ignore
        } else if message->Agent__Task__Message.isAssistantMessage {
          // Assistant message without tool calls - complete task if still working
          switch task.status {
          | Agent__Task.Status.Working(_) => {
              Console.log("=== Assistant message complete - finishing task")
              let _ = executeTaskCommand(
                agent,
                task.id,
                TaskCommands.Complete({message: Some(message)}),
              )
            }
          | _ => Console.log("=== Task not in Working status, skipping completion")
          }
        } // Tool message added - continue iteration
        else if message->Agent__Task__Message.isToolMessage {
          Console.log("=== Tool message added - continuing iteration")
          Agent__AgenticLoop.runIteration(
            agent.llm,
            (taskId, cmd) => executeTaskCommand(agent, taskId, cmd),
            task,
          )->ignore
        }
        // Ignore System and User messages
      }
    | TaskEvent(_, Completed(_)) => Console.log("=== Task completed")
    | TaskEvent(_, Failed(_)) => Console.log("=== Task failed")
    | TaskEvent(_, Canceled(_)) => Console.log("=== Task canceled")
    | TaskEvent(_, Rejected(_)) => Console.log("=== Task rejected")
    | TaskEvent(_, InputRequested(_)) => Console.log("=== Input requested")
    | TaskEvent(_, Resumed(_)) => Console.log("=== Task resumed")
    | TaskEvent(_, ArtifactAdded(_)) => () // No reactor for artifacts yet
    }
  })
  unsubscribe
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = (agent: t, message: Agent__Task__Message.t): result<Agent__Task.t, string> => {
  switch message->Agent__Task__Message.getTaskId {
  | Some(id) => executeTaskCommand(agent, id, TaskCommands.AddMessage({message: message}))
  | None => {
      let newId = Agent__Id.make()
      executeTaskCommand(agent, newId, TaskCommands.Create({initialMessage: message}))
    }
  }
}
