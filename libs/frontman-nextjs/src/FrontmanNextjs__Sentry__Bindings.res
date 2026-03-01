// Sentry SDK bindings for ReScript
// Using @sentry/nextjs for Next.js integration
// Types are shared via FrontmanBindings.Sentry__Types

module Types = FrontmanBindings.Sentry__Types

// Re-export shared types for convenience
type severity = Types.severity
type breadcrumb = Types.breadcrumb
type eventHint = Types.eventHint
type sentryEvent = Types.sentryEvent
type scopeContext = Types.scopeContext
type transport = Types.transport

// Standard Sentry init options
type initOptions = {
  dsn: string,
  environment?: string,
  release?: string,
  sampleRate?: float,
  tracesSampleRate?: float,
  debug?: bool,
  enabled?: bool,
  initialScope?: scopeContext,
  beforeSend?: (sentryEvent, eventHint) => Nullable.t<sentryEvent>,
}

type initOptionsWithTransport = {
  dsn: string,
  environment?: string,
  release?: string,
  sampleRate?: float,
  tracesSampleRate?: float,
  debug?: bool,
  enabled?: bool,
  initialScope?: scopeContext,
  transport: transport,
  beforeSend?: (sentryEvent, eventHint) => Nullable.t<sentryEvent>,
}

// Main Sentry functions from @sentry/nextjs
@module("@sentry/nextjs") external init: initOptions => unit = "init"
@module("@sentry/nextjs") external initWithTransport: initOptionsWithTransport => unit = "init"
@module("@sentry/nextjs")
external captureException: (exn, ~hint: eventHint=?) => string = "captureException"
@module("@sentry/nextjs")
external captureMessage: (string, ~level: severity=?) => string = "captureMessage"
@module("@sentry/nextjs") external setTag: (string, string) => unit = "setTag"
@module("@sentry/nextjs") external setTags: Dict.t<string> => unit = "setTags"
@module("@sentry/nextjs") external setExtra: (string, JSON.t) => unit = "setExtra"
@module("@sentry/nextjs") external setExtras: Dict.t<JSON.t> => unit = "setExtras"
@module("@sentry/nextjs") external setContext: (string, Dict.t<JSON.t>) => unit = "setContext"
@module("@sentry/nextjs") external addBreadcrumb: breadcrumb => unit = "addBreadcrumb"
@module("@sentry/nextjs") external isInitialized: unit => bool = "isInitialized"

// Scope manipulation
type scope
@module("@sentry/nextjs") external withScope: (scope => 'a) => 'a = "withScope"
@send external scopeSetTag: (scope, string, string) => unit = "setTag"
@send external scopeSetExtra: (scope, string, JSON.t) => unit = "setExtra"
@send external scopeSetContext: (scope, string, Dict.t<JSON.t>) => unit = "setContext"

// Flush pending events
@module("@sentry/nextjs") external flush: int => promise<bool> = "flush"
