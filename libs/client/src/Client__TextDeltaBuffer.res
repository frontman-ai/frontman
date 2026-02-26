// Text delta buffering (rAF-based throttle)
//
// Instead of dispatching a state update for every streaming chunk from the server,
// accumulate text deltas and flush once per animation frame (~60fps).
// This prevents dozens of full state rebuilds per second during fast streaming.
//
// Separated into its own module so both FrontmanProvider (producer) and
// StateReducer (consumer needing to flush before TurnCompleted) can access it
// without circular dependencies.

type t = {
  add: (~taskId: string, ~text: string) => unit,
  flush: unit => unit,
  reset: unit => unit,
}

let make = (~onFlush: (~taskId: string, ~text: string) => unit): t => {
  let buffer = ref(Dict.make())
  let rafId: ref<option<int>> = ref(None)

  let flush = () => {
    let pending = buffer.contents
    buffer := Dict.make()
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    pending->Dict.forEachWithKey((text, taskId) => {
      onFlush(~taskId, ~text)
    })
  }

  let add = (~taskId: string, ~text: string) => {
    let current = buffer.contents->Dict.get(taskId)->Option.getOr("")
    buffer.contents->Dict.set(taskId, current ++ text)
    switch rafId.contents {
    | Some(_) => () // Already scheduled
    | None =>
      rafId := Some(WebAPI.Global.requestAnimationFrame(_ => flush()))
    }
  }

  let reset = () => {
    switch rafId.contents {
    | Some(id) => WebAPI.Global.cancelAnimationFrame(id)
    | None => ()
    }
    rafId := None
    buffer := Dict.make()
  }

  {add, flush, reset}
}

// Active instance — set by FrontmanProvider, read by StateReducer.
// This is the only module-level state; all buffer state lives in closures.
let active: ref<option<t>> = ref(None)

let flush = () =>
  switch active.contents {
  | Some(instance) => instance.flush()
  | None => ()
  }
