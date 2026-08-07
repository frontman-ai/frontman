@@warning("-30")

type lockMode =
  | @as("exclusive") Exclusive
  | @as("shared") Shared

@editor.completeFrom(LockManager)
type lockManager = private {}

type lock = {
  name: string,
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
