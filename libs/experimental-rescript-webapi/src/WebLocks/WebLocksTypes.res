@@warning("-30")

type lockMode =
  | @as("exclusive") Exclusive
  | @as("shared") Shared

/**
[See LockManager on MDN](https://developer.mozilla.org/docs/Web/API/LockManager)
*/
@editor.completeFrom(LockManager)
type lockManager = private {}

/**
[See Lock on MDN](https://developer.mozilla.org/docs/Web/API/Lock)
*/
type lock = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Lock/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Lock/mode)
    */
  mode: lockMode,
}

type lockInfo = {
  mutable name?: string,
  mutable mode?: lockMode,
  mutable clientId?: string,
}

type lockManagerSnapshot = {
  mutable held?: array<lockInfo>,
  mutable pending?: array<lockInfo>,
}

type lockOptions = {
  mutable mode?: lockMode,
  mutable ifAvailable?: bool,
  mutable steal?: bool,
  mutable signal?: EventTypes.abortSignal,
}

type lockGrantedCallback = lock => promise<JSON.t>
