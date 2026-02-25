// Text delta buffering (rAF-based throttle)
// Instead of dispatching a state update for every streaming chunk from the server,
// accumulate text deltas and flush once per animation frame (~60fps).
// This prevents dozens of full state rebuilds per second during fast streaming.
//
// Separated into its own module so both FrontmanProvider (producer) and
// StateReducer (consumer needing to flush before TurnCompleted) can access it
// without circular dependencies.
//
// The flush callback is injected at init time to break the dependency cycle
// (this module cannot import Client__State without creating a circular dep).

@val external requestAnimationFrame: (unit => unit) => int = "requestAnimationFrame"
@val external cancelAnimationFrame: int => unit = "cancelAnimationFrame"

let buffer: ref<Dict.t<string>> = ref(Dict.make())
let rafId: ref<option<int>> = ref(None)

// Injected callback: (taskId, text) => dispatch text delta action
let onFlush: ref<option<(~taskId: string, ~text: string) => unit>> = ref(None)

let init = (~onTextDelta: (~taskId: string, ~text: string) => unit) => {
  onFlush := Some(onTextDelta)
}

let flush = () => {
  let pending = buffer.contents
  buffer := Dict.make()
  switch rafId.contents {
  | Some(id) => cancelAnimationFrame(id)
  | None => ()
  }
  rafId := None
  switch onFlush.contents {
  | Some(dispatch) =>
    pending->Dict.forEachWithKey((text, taskId) => {
      dispatch(~taskId, ~text)
    })
  | None => ()
  }
}

let add = (~taskId: string, ~text: string) => {
  let current = buffer.contents->Dict.get(taskId)->Option.getOr("")
  buffer.contents->Dict.set(taskId, current ++ text)
  switch rafId.contents {
  | Some(_) => () // Already scheduled
  | None =>
    rafId := Some(requestAnimationFrame(_ => flush()))
  }
}

let reset = () => {
  switch rafId.contents {
  | Some(id) => cancelAnimationFrame(id)
  | None => ()
  }
  rafId := None
  buffer := Dict.make()
}
