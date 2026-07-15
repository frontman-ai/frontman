// ACP message chunk buffering.
//
// Instead of dispatching a state update for every streaming chunk from the server,
// accumulate assistant text deltas and flush once per animation frame (~60fps).
// This prevents dozens of full state rebuilds per second during fast streaming.
// User blocks remain grouped until the next protocol update boundary so paired
// resources such as annotation screenshots are parsed together.
//
// Separated into its own module so both FrontmanProvider (producer) and
// StateReducer can flush streamed text before finalizing task state.
// without circular dependencies.

type entry = {
  text: string,
  timestamp: string,
  agentId: string,
}

type userEntry = {
  blocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
  timestamp: string,
  agentId: string,
}

type messageRole = Assistant | User

type identity = {
  role: messageRole,
  timestamp: string,
  agentId: string,
}

type t = {
  add: (
    ~taskId: string,
    ~messageId: string,
    ~text: string,
    ~timestamp: string,
    ~agentId: string,
  ) => unit,
  addUserBlock: (
    ~taskId: string,
    ~messageId: string,
    ~block: FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock,
    ~timestamp: string,
    ~agentId: string,
  ) => unit,
  flush: unit => unit,
  discardTask: string => unit,
  reset: unit => unit,
}

let make = (
  ~onFlush: (
    ~taskId: string,
    ~messageId: string,
    ~text: string,
    ~timestamp: string,
    ~agentId: string,
  ) => unit,
  ~onUserFlush: (
    ~taskId: string,
    ~messageId: string,
    ~blocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.contentBlock>,
    ~timestamp: string,
    ~agentId: string,
  ) => unit,
): t => {
  let buffer: ref<Dict.t<Dict.t<entry>>> = ref(Dict.make())
  let userBuffer: ref<Dict.t<Dict.t<userEntry>>> = ref(Dict.make())
  let owners: ref<Dict.t<string>> = ref(Dict.make())
  let identities: ref<Dict.t<Dict.t<identity>>> = ref(Dict.make())
  let rafId: ref<option<int>> = ref(None)

  let validateIdentity = (~taskId, ~messageId, ~role, ~timestamp, ~agentId) => {
    switch owners.contents->Dict.get(messageId) {
    | Some(existingTaskId) if existingTaskId != taskId =>
      failwith(`Message ${messageId} crossed tasks from ${existingTaskId} to ${taskId}`)
    | _ => ()
    }
    let messages = switch identities.contents->Dict.get(taskId) {
    | Some(messages) => messages
    | None => {
        let messages = Dict.make()
        identities.contents->Dict.set(taskId, messages)
        messages
      }
    }
    switch messages->Dict.get(messageId) {
    | Some(identity) if identity.role != role => failwith(`Message ${messageId} changed roles`)
    | Some(identity) if identity.agentId != agentId =>
      failwith(`Message ${messageId} changed agents from ${identity.agentId} to ${agentId}`)
    | Some(identity) if identity.timestamp != timestamp =>
      failwith(`Message ${messageId} changed timestamps from ${identity.timestamp} to ${timestamp}`)
    | Some(_) => ()
    | None => {
        owners.contents->Dict.set(messageId, taskId)
        messages->Dict.set(messageId, {role, timestamp, agentId})
      }
    }
  }

  let flushAssistant = () => {
    let pending = buffer.contents
    buffer := Dict.make()
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    pending->Dict.forEachWithKey((messages, taskId) => {
      messages->Dict.forEachWithKey((entry, messageId) => {
        onFlush(
          ~taskId,
          ~messageId,
          ~text=entry.text,
          ~timestamp=entry.timestamp,
          ~agentId=entry.agentId,
        )
      })
    })
  }

  let flushUsers = () => {
    let pending = userBuffer.contents
    userBuffer := Dict.make()
    pending->Dict.forEachWithKey((messages, taskId) =>
      messages->Dict.forEachWithKey((entry, messageId) =>
        onUserFlush(
          ~taskId,
          ~messageId,
          ~blocks=entry.blocks,
          ~timestamp=entry.timestamp,
          ~agentId=entry.agentId,
        )
      )
    )
  }

  let flush = () => {
    flushAssistant()
    flushUsers()
  }

  let discardTask = taskId => {
    identities.contents
    ->Dict.get(taskId)
    ->Option.forEach(messages =>
      messages
      ->Dict.keysToArray
      ->Array.forEach(messageId => owners.contents->Dict.delete(messageId))
    )
    buffer.contents->Dict.delete(taskId)
    userBuffer.contents->Dict.delete(taskId)
    identities.contents->Dict.delete(taskId)
    switch buffer.contents->Dict.keysToArray->Array.length == 0 {
    | true =>
      rafId.contents->Option.forEach(WebAPI.Global.cancelAnimationFrame)
      rafId := None
    | false => ()
    }
  }

  let add = (
    ~taskId: string,
    ~messageId: string,
    ~text: string,
    ~timestamp: string,
    ~agentId: string,
  ) => {
    validateIdentity(~taskId, ~messageId, ~role=Assistant, ~timestamp, ~agentId)
    flushUsers()
    let messages = switch buffer.contents->Dict.get(taskId) {
    | Some(messages) => messages
    | None => {
        let messages = Dict.make()
        buffer.contents->Dict.set(taskId, messages)
        messages
      }
    }
    let current = messages->Dict.get(messageId)
    let updatedEntry = switch current {
    | Some(existing) => {
        // Keep the first timestamp for all chunks in one protocol message.
        text: existing.text ++ text,
        timestamp: existing.timestamp,
        agentId,
      }
    | None => {text, timestamp, agentId}
    }
    messages->Dict.set(messageId, updatedEntry)
    switch rafId.contents {
    | Some(_) => () // Already scheduled
    | None => rafId := Some(WebAPI.Global.requestAnimationFrame(_ => flush()))
    }
  }
  let addUserBlock = (~taskId, ~messageId, ~block, ~timestamp, ~agentId) => {
    validateIdentity(~taskId, ~messageId, ~role=User, ~timestamp, ~agentId)
    flushAssistant()
    let current =
      userBuffer.contents
      ->Dict.get(taskId)
      ->Option.flatMap(messages =>
        messages->Dict.get(messageId)->Option.map(entry => (messages, entry))
      )
    switch current {
    | Some((messages, entry)) =>
      messages->Dict.set(messageId, {...entry, blocks: entry.blocks->Array.concat([block])})
    | None => {
        flushUsers()
        let messages = Dict.make()
        userBuffer.contents->Dict.set(taskId, messages)
        messages->Dict.set(messageId, {blocks: [block], timestamp, agentId})
      }
    }
  }

  let reset = () => {
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    buffer := Dict.make()
    userBuffer := Dict.make()
    owners := Dict.make()
    identities := Dict.make()
  }

  {add, addUserBlock, flush, discardTask, reset}
}

// Active instance — set by FrontmanProvider, read by StateReducer.
// This is the only module-level state; all buffer state lives in closures.
let active: ref<option<t>> = ref(None)

let flush = () => {
  switch active.contents {
  | Some(instance) => instance.flush()
  | None => ()
  }
}

let discardTask = taskId => {
  switch active.contents {
  | Some(instance) => instance.discardTask(taskId)
  | None => ()
  }
}
