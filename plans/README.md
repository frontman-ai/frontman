# Reducer and effect interpreter

## Decision

The reducer and effect interpreter have separate interfaces.
The store and React hook require an explicit, typed effect handler.
This replaces the combined contract without a compatibility adapter.

## Interfaces

- `StateReducer.Interface` exposes `state`, `action`, `effect`, `name`, and `next`.
- `next(state, action)` returns the next state and an array of effects.
- `StateReducer.effectHandler` receives an effect, the current state, and a dispatch function.
- `StateStore.make` and `StateReducer.useReducer` require `~handleEffect`.
- The compiler requires matching state, action, and effect types.
- Both packages treat non-exhaustive pattern matches as errors.

The client reducer interface exposes only its types, `name`, and `next`.
The client interpreter interface exposes only `handleEffect`.

## Dependencies

`Client__State__Protocol` owns the shared action and effect types.
The reducer and interpreter depend on this protocol, not on each other.
`Client__State__Store` connects the reducer, interpreter, and initial state.
Selectors and shared helpers have separate modules.

## Guarantees and limits

The compiler rejects a missing handler, mismatched handler types, and access to hidden module members.
The split preserves existing effect behavior and scheduling.
The public library API change requires a major release.

These interfaces do not prove purity or enforce the dependency direction.
ReScript still permits browser calls, clock reads, randomness, and mutation inside `next`.
Explicit reducer inputs, runtime resource ownership, and stale-completion handling remain separate work.
