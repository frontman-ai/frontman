// Frontman Sentry integration for browser client
// Reports errors to Frontman's own Sentry project

module Bindings = FrontmanClient__Sentry__Bindings
module SentryConfig = FrontmanBindings.Bindings__Sentry__Config
module SentryFilter = FrontmanBindings.Bindings__Sentry__Filter

let initialized = ref(false)

let initialize = (~transport: option<Bindings.transport>=?) => {
  // Skip Sentry in Frontman internal dev; custom transport (tests) always initializes
  if !initialized.contents && (Option.isSome(transport) || !SentryConfig.isInternalDev()) {
    Bindings.init({
      dsn: SentryConfig.dsn,
      environment: %raw(`typeof window !== 'undefined' && window.location?.hostname === 'localhost' ? 'development' : 'production'`),
      sampleRate: 1.0,
      ?transport,
      initialScope: {
        tags: Dict.fromArray([("frontman.library", "frontman-client")]),
      },
      beforeSend: SentryFilter.beforeSend,
    })
    initialized.contents = true
  }
}

let isEnabled = () => initialized.contents && Bindings.isInitialized()

let captureConnectionError = (message: string, ~endpoint: string) => {
  if isEnabled() {
    Bindings.withScope(scope => {
      scope->Bindings.scopeSetTag("frontman.library", "frontman-client")
      scope->Bindings.scopeSetTag("frontman.operation", "connection")
      scope->Bindings.scopeSetContext(
        "connection",
        Dict.fromArray([("endpoint", JSON.Encode.string(endpoint))]),
      )
      Bindings.captureMessage(message, ~level=#error)->ignore
    })
  }
}

type protocol = [#ACP | #MCP]

let captureProtocolError = (message: string, ~protocol: protocol, ~operation: string) => {
  if isEnabled() {
    let protocolStr = switch protocol {
    | #ACP => "ACP"
    | #MCP => "MCP"
    }
    Bindings.withScope(scope => {
      scope->Bindings.scopeSetTag("frontman.library", "frontman-client")
      scope->Bindings.scopeSetTag("frontman.protocol", protocolStr)
      scope->Bindings.scopeSetTag("frontman.operation", operation)
      Bindings.captureMessage(message, ~level=#error)->ignore
    })
  }
}

let captureException = (error: exn, ~operation: option<string>=?) => {
  if isEnabled() {
    Bindings.withScope(scope => {
      scope->Bindings.scopeSetTag("frontman.library", "frontman-client")
      switch operation {
      | Some(op) => scope->Bindings.scopeSetTag("frontman.operation", op)
      | None => ()
      }
      Bindings.captureException(error)->ignore
    })
  }
}

type breadcrumbCategory = [#connection | #acp | #mcp | #session]

let addBreadcrumb = (~category: breadcrumbCategory, ~message: string) => {
  if isEnabled() {
    let categoryStr = switch category {
    | #connection => "connection"
    | #acp => "acp"
    | #mcp => "mcp"
    | #session => "session"
    }
    Bindings.addBreadcrumb({
      category: categoryStr,
      message,
      level: #info,
    })
  }
}
