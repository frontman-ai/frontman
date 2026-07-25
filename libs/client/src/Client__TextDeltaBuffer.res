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
  agentId: string,
}

type userEntry = {
  blocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t>,
  agentId: string,
}

type t = {
  add: (~taskId: string, ~messageId: string, ~text: string, ~agentId: string) => unit,
  addUserBlock: (
    ~taskId: string,
    ~messageId: string,
    ~block: FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t,
    ~agentId: string,
  ) => unit,
  flush: unit => unit,
  discardTask: string => unit,
  reset: unit => unit,
}

let taskEntries = (store: ref<Dict.t<Dict.t<'a>>>, taskId): Dict.t<'a> =>
  switch store.contents->Dict.get(taskId) {
  | Some(entries) => entries
  | None => {
      let entries = Dict.make()
      store.contents->Dict.set(taskId, entries)
      entries
    }
  }

let make = (
  ~onFlush: (~taskId: string, ~messageId: string, ~text: string, ~agentId: string) => unit,
  ~onUserFlush: (
    ~taskId: string,
    ~messageId: string,
    ~blocks: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t>,
    ~agentId: string,
  ) => unit,
): t => {
  let buffer: ref<Dict.t<Dict.t<entry>>> = ref(Dict.make())
  let userBuffer: ref<Dict.t<Dict.t<userEntry>>> = ref(Dict.make())
  let rafId: ref<option<int>> = ref(None)

  let cancelFlush = () => {
    rafId.contents->Option.forEach(WebAPI.Global.cancelAnimationFrame)
    rafId := None
  }

  let flushAssistant = () => {
    let pending = buffer.contents
    buffer := Dict.make()
    cancelFlush()
    pending->Dict.forEachWithKey((messages, taskId) =>
      messages->Dict.forEachWithKey((entry, messageId) =>
        onFlush(~taskId, ~messageId, ~text=entry.text, ~agentId=entry.agentId)
      )
    )
  }

  let flushUsers = () => {
    let pending = userBuffer.contents
    userBuffer := Dict.make()
    pending->Dict.forEachWithKey((messages, taskId) =>
      messages->Dict.forEachWithKey((entry, messageId) =>
        onUserFlush(~taskId, ~messageId, ~blocks=entry.blocks, ~agentId=entry.agentId)
      )
    )
  }

  let flush = () => {
    flushAssistant()
    flushUsers()
  }

  let discardTask = taskId => {
    buffer.contents->Dict.delete(taskId)
    userBuffer.contents->Dict.delete(taskId)
    switch buffer.contents->Dict.keysToArray->Array.length == 0 {
    | true => cancelFlush()
    | false => ()
    }
  }

  let add = (~taskId: string, ~messageId: string, ~text: string, ~agentId: string) => {
    flushUsers()
    let messages = taskEntries(buffer, taskId)
    let current = messages->Dict.get(messageId)
    let updatedEntry = switch current {
    | Some(existing) => {text: existing.text ++ text, agentId}
    | None => {text, agentId}
    }
    messages->Dict.set(messageId, updatedEntry)
    switch rafId.contents {
    | Some(_) => () // Already scheduled
    | None => rafId := Some(WebAPI.Global.requestAnimationFrame(_ => flush()))
    }
  }
  let addUserBlock = (~taskId, ~messageId, ~block, ~agentId) => {
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
        taskEntries(userBuffer, taskId)->Dict.set(messageId, {blocks: [block], agentId})
      }
    }
  }

  let reset = () => {
    cancelFlush()
    buffer := Dict.make()
    userBuffer := Dict.make()
  }

  {add, addUserBlock, flush, discardTask, reset}
}

// Active instance — set by FrontmanProvider, read by StateReducer.
// This is the only module-level state; all buffer state lives in closures.
let active: ref<option<t>> = ref(None)

let flush = () => active.contents->Option.forEach(instance => instance.flush())

let discardTask = taskId =>
  active.contents->Option.forEach(instance => instance.discardTask(taskId))
