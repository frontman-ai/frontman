// Text delta buffering (rAF-based throttle)
//
// Instead of dispatching a state update for every streaming chunk from the server,
// accumulate text deltas and flush once per animation frame (~60fps).
// This prevents dozens of full state rebuilds per second during fast streaming.
//
// Separated into its own module so both FrontmanProvider (producer) and
// StateReducer can flush streamed text before finalizing task state.
// without circular dependencies.

type entry = {
  text: string,
  timestamp: string,
  agentId: string,
}

type t = {
  selectAgent: (~taskId: string, ~agentId: string) => unit,
  add: (~taskId: string, ~text: string, ~timestamp: string) => unit,
  flush: unit => unit,
  reset: unit => unit,
}

let make = (
  ~onFlush: (~taskId: string, ~text: string, ~timestamp: string, ~agentId: string) => unit,
): t => {
  let buffer: ref<Dict.t<entry>> = ref(Dict.make())
  let selectedAgents: ref<Dict.t<string>> = ref(Dict.make())
  let rafId: ref<option<int>> = ref(None)

  let flush = () => {
    let pending = buffer.contents
    buffer := Dict.make()
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    pending->Dict.forEachWithKey((entry, taskId) => {
      onFlush(~taskId, ~text=entry.text, ~timestamp=entry.timestamp, ~agentId=entry.agentId)
    })
  }

  let selectAgent = (~taskId: string, ~agentId: string) => {
    flush()
    selectedAgents.contents->Dict.set(taskId, agentId)
  }

  let add = (~taskId: string, ~text: string, ~timestamp: string) => {
    let agentId =
      selectedAgents.contents
      ->Dict.get(taskId)
      ->Option.getOrThrow(~message=`Missing selected agent for task ${taskId}`)
    let current = buffer.contents->Dict.get(taskId)
    let updatedEntry = switch current {
    | Some(existing) if existing.agentId == agentId => {
        // Keep the first timestamp (subsequent chunks for the same task don't override)
        text: existing.text ++ text,
        timestamp: existing.timestamp,
        agentId,
      }
    | Some(_) => failwith(`Agent changed while text remained buffered for task ${taskId}`)
    | None => {text, timestamp, agentId}
    }
    buffer.contents->Dict.set(taskId, updatedEntry)
    switch rafId.contents {
    | Some(_) => () // Already scheduled
    | None => rafId := Some(WebAPI.Global.requestAnimationFrame(_ => flush()))
    }
  }

  let reset = () => {
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    buffer := Dict.make()
    selectedAgents := Dict.make()
  }

  {selectAgent, add, flush, reset}
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
