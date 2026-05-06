// Sentry log handler — automatically reports Log.error calls to Sentry.
//
// Registered alongside the Console handler so every Log.error(...)
// automatically sends to Sentry without manual captureMessage/captureException
// calls at each error site.
//
// When ~error is provided (JsExn.t), uses captureException for proper
// stack traces and Sentry issue grouping.  Otherwise uses captureMessage.

module Bindings = FrontmanBindings.Sentry__Browser
module Sentry = FrontmanClient__Sentry

let run = (~component, ~stacktrace as _, ~level, message, _ctx, error) => {
  switch level {
  | FrontmanLogs.Logs_level.Error =>
    if Sentry.isEnabled() {
      Bindings.withScope(scope => {
        scope->Bindings.scopeSetTag("frontman.library", "frontman-client")
        scope->Bindings.scopeSetTag("frontman.component", component)
        switch error {
        | Some(jsExn) =>
          // captureException preserves stack traces for Sentry grouping.
          // JsExn.t and exn are the same runtime representation in JS.
          Bindings.captureException((Obj.magic(jsExn): exn))->ignore
        | None => Bindings.captureMessage(message, ~level=#error)->ignore
        }
      })
    }
  | _ => ()
  }
}

let handler: FrontmanLogs.Logs.Handler.t = {
  id: "sentry",
  run,
}
