// Frontman Sentry integration for browser client
// Reports errors to Frontman's own Sentry project

module Bindings = FrontmanClient__Sentry__Bindings

// Frontman's Sentry DSN - public (client-side DSNs are always public)
let dsn = "https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296"

let initialized = ref(false)

let initialize = (~transport: option<Bindings.transport>=?) => {
  if !initialized.contents {
    Bindings.init({
      dsn,
      environment: %raw(`typeof window !== 'undefined' && window.location?.hostname === 'localhost' ? 'development' : 'production'`),
      sampleRate: 1.0,
      ?transport,
      initialScope: {
        tags: Dict.fromArray([("frontman.library", "frontman-client")]),
      },
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
