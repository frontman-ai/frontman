module Bindings = FrontmanBindings

let envValueIsEnabled = (value: string): bool =>
  switch value->String.trim->String.toLowerCase {
  | "1" | "true" => true
  | _ => false
  }

let isRuntimeEnabled = (): bool => {
  let env = Bindings.Process.env

  switch env->Dict.get("FRONTMAN_ENABLED") {
  | Some(value) => envValueIsEnabled(value)
  | None =>
    switch env->Dict.get("NODE_ENV") {
    | Some("development") => true
    | _ =>
      env
      ->Dict.get("FRONTMAN_ENABLE_IN_PRODUCTION")
      ->Option.map(envValueIsEnabled)
      ->Option.getOr(false)
    }
  }
}
