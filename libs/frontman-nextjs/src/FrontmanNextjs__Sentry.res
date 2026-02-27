// Frontman Sentry integration for Next.js library
// Reports errors to Frontman's own Sentry project

module Bindings = FrontmanNextjs__Sentry__Bindings
module SentryConfig = FrontmanBindings.Bindings__Sentry__Config
module SentryFilter = FrontmanBindings.Bindings__Sentry__Filter

let initialized = ref(false)

let initialize = (~transport: option<Bindings.transport>=?) => {
  // Skip Sentry in Frontman internal dev; custom transport (tests) always initializes
  if !initialized.contents && (Option.isSome(transport) || !SentryConfig.isInternalDev()) {
    let scope: Bindings.scopeContext = {
      tags: Dict.fromArray([("frontman.library", "frontman-nextjs")]),
    }
    switch transport {
    | Some(t) =>
      Bindings.initWithTransport({
        dsn: SentryConfig.dsn,
        environment: %raw(`process.env.NODE_ENV || "development"`),
        release: %raw(`process.env.npm_package_version || "unknown"`),
        sampleRate: 1.0,
        transport: t,
        initialScope: scope,
        beforeSend: SentryFilter.beforeSend,
      })
    | None =>
      Bindings.init({
        dsn: SentryConfig.dsn,
        environment: %raw(`process.env.NODE_ENV || "development"`),
        release: %raw(`process.env.npm_package_version || "unknown"`),
        sampleRate: 1.0,
        initialScope: scope,
        beforeSend: SentryFilter.beforeSend,
      })
    }
    initialized.contents = true
  }
}

let isEnabled = () => initialized.contents && Bindings.isInitialized()

let captureError = (error: exn, ~operation: option<string>=?, ~extra: option<Dict.t<JSON.t>>=?) => {
  if isEnabled() {
    Some(Bindings.withScope(scope => {
      scope->Bindings.scopeSetTag("frontman.library", "frontman-nextjs")

      switch operation {
      | Some(op) => scope->Bindings.scopeSetTag("frontman.operation", op)
      | None => ()
      }

      switch extra {
      | Some(data) => scope->Bindings.scopeSetContext("frontman", data)
      | None => ()
      }

      Bindings.captureException(error)
    }))
  } else {
    None
  }
}

let captureMessage = (
  message: string,
  ~level: Bindings.severity=#error,
  ~operation: option<string>=?,
) => {
  if isEnabled() {
    Some(Bindings.withScope(scope => {
      scope->Bindings.scopeSetTag("frontman.library", "frontman-nextjs")

      switch operation {
      | Some(op) => scope->Bindings.scopeSetTag("frontman.operation", op)
      | None => ()
      }

      Bindings.captureMessage(message, ~level)
    }))
  } else {
    None
  }
}

let addBreadcrumb = (~category: string, ~message: string, ~data: option<Dict.t<JSON.t>>=?) => {
  if isEnabled() {
    Bindings.addBreadcrumb({
      category,
      message,
      level: #info,
      ?data,
    })
  }
}

let flush = (~timeout: int=2000) => Bindings.flush(timeout)
