type entry = {clientId: string, runtime: Client__PreviewRuntime.t}

let current: ref<option<entry>> = ref(None)

let register = (~clientId, ~runtime): unit => current := Some({clientId, runtime})

let unregister = (~runtime: Client__PreviewRuntime.t): unit =>
  switch current.contents {
  | Some(active) if active.runtime === runtime => current := None
  | Some(_) | None => ()
  }

let get = (~clientId): option<Client__PreviewRuntime.t> =>
  switch current.contents {
  | Some(active) if active.clientId === clientId => Some(active.runtime)
  | Some(_) | None => None
  }

let describe = () =>
  switch current.contents {
  | Some({clientId}) => `active: ${clientId}`
  | None => "none"
  }
