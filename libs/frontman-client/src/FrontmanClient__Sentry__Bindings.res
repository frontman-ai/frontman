// Sentry SDK bindings for ReScript
// Using @sentry/browser for browser client
// Types are shared via FrontmanBindings.Bindings__Sentry__Types

module Types = FrontmanBindings.Bindings__Sentry__Types

// Re-export shared types for convenience
type severity = Types.severity
type breadcrumb = Types.breadcrumb
type eventHint = Types.eventHint
type sentryEvent = Types.sentryEvent
type scopeContext = Types.scopeContext
type transport = Types.transport

type initOptions = {
  dsn: string,
  environment?: string,
  release?: string,
  sampleRate?: float,
  debug?: bool,
  enabled?: bool,
  initialScope?: scopeContext,
  transport?: transport,
  beforeSend?: (sentryEvent, eventHint) => Nullable.t<sentryEvent>,
}

// Main Sentry functions from @sentry/browser
@module("@sentry/browser") external init: initOptions => unit = "init"
@module("@sentry/browser")
external captureException: (exn, ~hint: eventHint=?) => string = "captureException"
@module("@sentry/browser")
external captureMessage: (string, ~level: severity=?) => string = "captureMessage"
@module("@sentry/browser") external setTag: (string, string) => unit = "setTag"
@module("@sentry/browser") external setTags: Dict.t<string> => unit = "setTags"
@module("@sentry/browser") external setExtra: (string, JSON.t) => unit = "setExtra"
@module("@sentry/browser") external setExtras: Dict.t<JSON.t> => unit = "setExtras"
@module("@sentry/browser") external setContext: (string, Dict.t<JSON.t>) => unit = "setContext"
@module("@sentry/browser") external addBreadcrumb: breadcrumb => unit = "addBreadcrumb"
@module("@sentry/browser") external isInitialized: unit => bool = "isInitialized"

// Scope manipulation
type scope
@module("@sentry/browser") external withScope: (scope => 'a) => 'a = "withScope"
@send external scopeSetTag: (scope, string, string) => unit = "setTag"
@send external scopeSetExtra: (scope, string, JSON.t) => unit = "setExtra"
@send external scopeSetContext: (scope, string, Dict.t<JSON.t>) => unit = "setContext"
