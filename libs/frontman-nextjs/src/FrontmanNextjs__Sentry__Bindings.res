// Sentry SDK bindings for ReScript
// Using @sentry/nextjs for Next.js integration

type severity = [#fatal | #error | #warning | #log | #info | #debug]

type breadcrumb = {
  category?: string,
  message?: string,
  level?: severity,
  data?: Dict.t<JSON.t>,
}

type eventHint = {originalException?: exn}

type sentryEvent

type scopeContext = {
  tags?: Dict.t<string>,
  extra?: Dict.t<JSON.t>,
  user?: {id?: string, email?: string, username?: string},
}

// Transport type for custom transports (e.g., sentry-testkit)
type transport = FrontmanBindings.Bindings__Sentry__Transport.t

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
