// Main Agent module - entry point
S.enableJson()

module Bindings = AskTheLlmBindings
module ContextLoader = AskTheLlmContextLoader.ContextLoader

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
module Effect = Agent__Effect
module Command = Agent__Command
module CommandQueue = Agent__CommandQueue
module Reactor = Agent__Reactor

type t = {
  projectRoot: string,
  eventBus: ref<Agent__EventBus.t>,
  tasks: Agent__Tasks.t,
  llm: Adapters.Vercel.t,
  config: Agent__Config.t,
  toolRegistry: Agent__ToolsRegistry.t,
  commandQueue: Agent__CommandQueue.t,
  context: option<ContextLoader.loadedContext>,
}
type config = Agent__Config.t

let make = async (config: config) => {
  Agent__Logger.Log.info(`Initializing agent for project: ${config.projectRoot}`)

  // Load context files
  let contextResult = await ContextLoader.load({
    cwd: config.projectRoot,
    root: config.projectRoot,
  })

  let context = switch contextResult {
  | Ok(ctx) => {
      Agent__Logger.Log.info(
        `Loaded ${ctx.files
          ->Array.length
          ->Int.toString} context files (${ctx.totalSize->Int.toString} characters)`,
      )
      Some(ctx)
    }
  | Error(msg) => {
      Agent__Logger.Log.error(`Failed to load context: ${msg}`)
      None
    }
  }

  let eventBus = Agent__EventBus.make()

  // Use provided toolRegistry for testing, or create default registry with all tools
  let toolRegistry = config.toolRegistry->Option.getOr(Agent__ToolsRegistry.make())

  // Use provided model or create default OpenAI model
  let model = config.model->Option.getOr(Agent__Bindings__Vercel.OpenAI.gpt4o(config.apiKey))
  let llm = Agent__Adapters__Vercel.makeLLM(~model, ~toolRegistry)

  Agent__Logger.Log.info(`Agent initialized with ${toolRegistry->Array.length->Int.toString} tools`)

  {
    projectRoot: config.projectRoot,
    eventBus: ref(eventBus),
    tasks: Agent__Tasks.make(),
    llm,
    config,
    toolRegistry,
    commandQueue: Agent__CommandQueue.make(),
    context,
  }
}

// Subscribe to events and return unsubscribe function
let subscribe = (agent: t, handler: Agent__EventBus.subscriber): (unit => unit) => {
  let oldBus = agent.eventBus.contents
  let newBus = oldBus->Agent__EventBus.on(handler)
  agent.eventBus := newBus
  Agent__Logger.Log.debug(
    `[Agent] Subscribed - subscriber count: ${newBus.subs->Array.length->Int.toString}`,
  )

  // Return unsubscribe function
  () => {
    agent.eventBus := agent.eventBus.contents->Agent__EventBus.off(handler)
  }
}

let emit = (agent: t, event: Agent__EventBus.events): unit => {
  let bus = agent.eventBus.contents
  Agent__Logger.Log.debug(
    `[Agent] Emitting event to subscribers: ${bus.subs->Array.length->Int.toString}`,
  )
  bus->Agent__EventBus.emit(event)
}

// Main execution loop - drains command queue
let run = async (agent: t) => {
  await agent.commandQueue->Agent__CommandQueue.drain(async command => {
    switch command {
    | Domain({task, cmd}) =>
      switch Agent__Task.decide(task, cmd) {
      | Ok(events) => {
          let newTaskResult = events->List.reduce(Ok(task), (acc, event) => {
            switch acc {
            | Ok(currentTask) =>
              Agent__Task.evolve(currentTask, event, agent.context)->Result.map(t => Some(t))
            | Error(_) as err => err
            }
          })

          switch newTaskResult {
          | Ok(Some(updatedTask)) => {
              Agent__Tasks.update(agent.tasks, updatedTask)
              events->List.forEach(event => {
                agent->emit(Agent__EventBus.TaskEvent(updatedTask.id, event))
              })
            }
          | Ok(None) =>
            Agent__Logger.Log.error("Internal error: evolve returned None after decide succeeded")
          | Error(msg) => Agent__Logger.Log.error(`Event application failed: ${msg}`)
          }
        }
      | Error(msg) => Agent__Logger.Log.error(`Domain command failed: ${msg}`)
      }
    | Effect(effect) => {
        let task = Agent__Command.getTask(command)
        let commandsResult = await Agent__Effect.execute(
          agent.config,
          effect,
          ~toolRegistry=agent.toolRegistry,
          ~llm=agent.llm,
          ~emitEvent=event => agent->emit(event),
        )

        switch commandsResult {
        | Ok(commands) =>
          commands->Array.forEach(cmd => {
            agent.commandQueue->Agent__CommandQueue.enqueue(Domain({task, cmd}))
          })
        | Error(msg) => Agent__Logger.Log.error(`Effect execution failed: ${msg}`)
        }
      }
    }
  })
}

let initialize = (agent: t): (unit => unit) => {
  let unsubscribe = agent->subscribe(event => {
    let taskId = Agent__EventBus.getTaskIdFromEvent(event)
    let task = agent.tasks->Agent__Tasks.get(taskId)
    let commands = task->Option.map(Agent__Reactor.react(_, event))->Option.getOr(list{})

    // Enqueue all commands and trigger run
    commands->List.forEach(cmd => {
      agent.commandQueue->Agent__CommandQueue.enqueue(cmd)
    })

    // Trigger run if we enqueued commands
    if commands->List.length > 0 {
      run(agent)->ignore
    }
  })
  Agent__Logger.Log.info("Agent initialized and listening for domain events...")
  unsubscribe
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = async (agent: t, message: Agent__Task__Message.t) => {
  let command =
    message
    ->Agent__Task__Message.getTaskId
    ->Agent__Tasks.get(agent.tasks, _)
    ->Option.map(task => {
      Agent__Command.Domain({task: Some(task), cmd: AddMessage({task, message})})
    })
    ->Option.getOr({
      Agent__Command.Domain({
        task: None,
        cmd: Create({initialMessage: message, context: agent.context}),
      })
    })

  // Enqueue command and trigger run
  agent.commandQueue->Agent__CommandQueue.enqueue(command)
  await agent->run
}
