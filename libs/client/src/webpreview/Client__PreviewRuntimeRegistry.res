let current: ref<option<Client__PreviewRuntime.t>> = ref(None)

let register = (~runtime: Client__PreviewRuntime.t): unit => current := Some(runtime)

let unregister = (~runtime: Client__PreviewRuntime.t): unit =>
  switch current.contents {
  | Some(active) if active === runtime => current := None
  | Some(_) | None => ()
  }

let get = (): option<Client__PreviewRuntime.t> => current.contents

let describe = () =>
  switch current.contents {
  | Some(_) => "active"
  | None => "none"
  }
