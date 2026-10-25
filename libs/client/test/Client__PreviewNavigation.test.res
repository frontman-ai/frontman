open Vitest
module Task = Client__State__Types.Task
module Reducer = Client__Task__Reducer
module State = Client__State__StateReducer
let url = "http://localhost:3000/preview"

test("late frame and URL observations cannot update a switched task or replaced iframe", t => {
  let first = Task.makeNew(~previewUrl=url)
  let second = Task.makeNew(~previewUrl=url ++ "/second")
  let switched = {...State.defaultState, currentTask: Task.New(second)}
  let stale = action => State.PreviewAction({
    clientId: Task.getClientId(first),
    navigationKey: 0,
    action,
  })
  [
    Reducer.SetPreviewUrl({url: url ++ "/stale"}),
    SetPreviewFrame({contentDocument: None, contentWindow: None}),
  ]->Array.forEach(action => {
    let (unchanged, effects) = State.next(switched, stale(action))
    t->expect(unchanged)->Expect.toBe(switched)
    t->expect(effects)->Expect.toEqual([])
  })
  let state = {...State.defaultState, currentTask: Task.New(first)}
  let (reset, _) = State.next(
    state,
    TaskAction({target: CurrentTask, action: NavigatePreview({url: url})}),
  )
  let (unchanged, effects) = State.next(reset, stale(SetPreviewUrl({url: url ++ "/stale"})))
  t->expect(unchanged)->Expect.toBe(reset)
  t->expect(effects)->Expect.toEqual([])
  let (accepted, _) = State.next(
    reset,
    PreviewAction({
      clientId: Task.getClientId(first),
      navigationKey: 1,
      action: SetPreviewUrl({url: url ++ "/observed"}),
    }),
  )
  t->expect(State.Selectors.previewUrl(accepted))->Expect.toBe(url ++ "/observed")
  t->expect(State.Selectors.previewFrame(accepted).navigationKey)->Expect.toBe(1)
})
