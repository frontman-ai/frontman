open Vitest
open StateReducer

module Expect = Vitest.Expect

module ReactTestingLibrary = Bindings__ReactTestingLibrary
module State = {
  type state = {
    sync: int,
    async: result<int, string>,
  }

  type action =
    | Id
    | Sync(int)
    | Async(int => promise<int>, int)
    | AsyncResult(result<int, string>)

  type effect = Effect(int => promise<int>, int)

  let name = "StateReducerTestState"

  let empty = () => {
    sync: 0,
    async: Ok(0),
  }

  let handleEffect = (effect, _state, next: action => unit): unit => {
    switch effect {
    | Effect(fn, x) =>
      fn(x)
      ->Promise.thenResolve(y => {
        AsyncResult(Ok(y))->next
      })
      ->Promise.ignore
    }
  }

  let next = (state, action) => {
    switch action {
    | Id => update(state)
    | Sync(x) => update({...state, sync: x})
    | Async(fn, x) => update(~sideEffect=Effect(fn, x), state)
    | AsyncResult(x) => update({...state, async: x})
    }
  }
}

describe("Initialization", () => {
  test("Running Next with ID shouldn't update Anything", t => {
    let {result} = ReactTestingLibrary.renderHook(
      () => StateReducer.useReducer(module(State), State.empty()),
    )
    let (state, _dispatch) = result.current
    t->expect(state)->Expect.toEqual(State.empty())
  })

  test("Running an action should work", t => {
    let {result} = ReactTestingLibrary.renderHook(
      () => StateReducer.useReducer(module(State), State.empty()),
    )
    ReactTestingLibrary.act(
      () => {
        let (_, dispatch) = result.current
        dispatch(Id)
      },
    )
    let (state, _dispatch) = result.current
    t->expect(state)->Expect.toEqual(State.empty())
  })
})

describe("Syncronous Updates", () => {
  test("Running Sync Actions should directly update", t => {
    let {result} = ReactTestingLibrary.renderHook(
      () => StateReducer.useReducer(module(State), State.empty()),
    )

    ReactTestingLibrary.act(
      () => {
        let (_, dispatch) = result.current
        dispatch(State.Sync(5))
        dispatch(State.Sync(16))
      },
    )
    let (state, _dispatch) = result.current

    t->expect(state.sync)->Expect.toEqual(16)
  })
})

describe("Asynchrounous Updates", () => {
  testAsync("Running async functions should update the state", t => {
    let {result} = ReactTestingLibrary.renderHook(
      () => StateReducer.useReducer(module(State), State.empty()),
    )
    ReactTestingLibrary.act(
      () => {
        let (_, dispatch) = result.current
        dispatch(State.Async(Promise.resolve, 100))
      },
    )

    ReactTestingLibrary.waitFor(
      () => {
        let (state, _) = result.current
        t->expect(state.async)->Expect.toEqual(Ok(100))
      },
    )
  })
})
