module Bindings = FrontmanBindings.Sentry__Browser
module Sentry = FrontmanClient__Sentry

let run = (~component, ~stacktrace as _, ~level, message, ctx, error) => {
  switch level {
  | FrontmanLogs.Logs_level.Error =>
    if Sentry.isEnabled() {
      Bindings.withScope(scope => {
        scope->Bindings.scopeSetTag("frontman.library", "frontman-client")
        scope->Bindings.scopeSetTag("frontman.component", component)
        scope->Bindings.scopeSetContext("frontman.log_context", Obj.magic(ctx))
        switch error {
        | Some(jsExn) => Bindings.captureException((Obj.magic(jsExn): exn))->ignore
        | None => Bindings.captureMessage(message, ~level=#error)->ignore
        }
      })
    }
  | _ => ()
  }
}

@@live
let handler: FrontmanLogs.Logs.Handler.t = {
  id: "sentry",
  run,
}
