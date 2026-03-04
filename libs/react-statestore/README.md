# @frontman-ai/react-statestore

ReScript state management for React with pure reducers and managed side effects.

Two tools that work well together (or standalone):

- **StateReducer** -- Local component state (like `useReducer` with side effects)
- **StateStore** -- Global state with concurrent-safe selectors (like Redux, but tiny)

## Installation

```bash
npm install @frontman-ai/react-statestore
```

Add to your `rescript.json`:

```json
{
  "dependencies": ["@frontman-ai/react-statestore"]
}
```

### Requirements

- ReScript 12+
- React 19+
- `@rescript/react` ^0.14.0

## Quick Start

### 1. Define your types

```rescript
// Counter__Types.res
type state = {count: int}
type action = Increment | Decrement | Reset
type effect = LogCount(int)
```

### 2. Implement the reducer

```rescript
// Counter__Reducer.res
type state = Counter__Types.state
type action = Counter__Types.action
type effect = Counter__Types.effect

let name = "Counter"

let next = (state, action) => {
  switch action {
  | Increment =>
    StateReducer.update(
      {count: state.count + 1},
      ~sideEffect=LogCount(state.count + 1),
    )
  | Decrement => StateReducer.update({count: state.count - 1})
  | Reset => StateReducer.update({count: 0})
  }
}

let handleEffect = (effect, _state, _dispatch) => {
  switch effect {
  | LogCount(n) => Console.log(`Count is now: ${n->Int.toString}`)
  }
}
```

### 3. Create a global store (optional)

```rescript
// Counter__Store.res
let store = StateStore.make(module(Counter__Reducer), {count: 0})
let dispatch = action => store->StateStore.dispatch(action)

module Selectors = {
  let count = (state: Counter__Types.state) => state.count
}
```

### 4. Use in components

```rescript
// With global store
@react.component
let make = () => {
  let count = StateStore.useSelector(Counter__Store.store, Counter__Store.Selectors.count)

  <div>
    <p>{React.string(`Count: ${count->Int.toString}`)}</p>
    <button onClick={_ => Counter__Store.dispatch(Increment)}>
      {React.string("+")}
    </button>
  </div>
}
```

```rescript
// With local state
@react.component
let make = () => {
  let (state, dispatch) = StateReducer.useReducer(module(Counter__Reducer), {count: 0})

  <div>
    <p>{React.string(`Count: ${state.count->Int.toString}`)}</p>
    <button onClick={_ => dispatch(Increment)}>
      {React.string("+")}
    </button>
  </div>
}
```

## API Reference

### StateReducer

#### `module type Interface`

The interface your reducer module must satisfy:

```rescript
module type Interface = {
  type state
  type action
  type effect
  let name: string
  let next: (state, action) => (state, array<effect>)
  let handleEffect: (effect, state, action => unit) => unit
}
```

#### `StateReducer.update(state, ~sideEffect=?, ~sideEffects=?)`

Helper to build the `(state, array<effect>)` return value from `next`:

```rescript
// No effects
StateReducer.update(newState)

// Single effect
StateReducer.update(newState, ~sideEffect=MyEffect)

// Multiple effects
StateReducer.update(newState, ~sideEffects=[Effect1, Effect2])
```

#### `StateReducer.useReducer(module(Reducer), initialState)`

React hook for local component state with managed side effects.

```rescript
let (state, dispatch) = StateReducer.useReducer(module(MyReducer), initialState)
```

### StateStore

#### `StateStore.make(module(Reducer), initialState)`

Create a global store instance:

```rescript
let store = StateStore.make(module(MyReducer), {count: 0})
```

#### `StateStore.dispatch(store, action)`

Dispatch an action to update state and run effects:

```rescript
store->StateStore.dispatch(Increment)
```

#### `StateStore.getState(store)`

Read current state outside of React:

```rescript
let currentState = StateStore.getState(store)
```

#### `StateStore.subscribe(store, callback)`

Subscribe to state changes. Returns an unsubscribe function:

```rescript
let unsubscribe = StateStore.subscribe(store, () => Console.log("state changed"))
```

#### `StateStore.useSelector(store, selector, ~compare=?)`

React hook that subscribes to a slice of state. Uses `useSyncExternalStoreWithSelector` for concurrent-mode safety. Components only re-render when the selected value changes.

```rescript
let count = StateStore.useSelector(store, state => state.count)
```

Custom equality:

```rescript
let items = StateStore.useSelector(
  ~compare=Some((a, b) => a.id == b.id),
  store,
  state => state.selectedItem,
)
```

## Design Principles

The `next` function is pure -- it computes new state and declares effects as data, with no side effects. Side effects are values returned from the reducer rather than callbacks; they run after the state update, so reducers stay testable without mocking.

The global store uses React's `useSyncExternalStoreWithSelector` to prevent tearing in concurrent mode. Selectors use custom structural equality that skips deep object comparison (assumes immutable state) while still handling array comparison.

## License

[Apache-2.0](./LICENSE)
