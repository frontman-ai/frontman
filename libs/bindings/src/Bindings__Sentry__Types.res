// Shared Sentry types used by all framework integrations
// These are SDK-agnostic — they describe the Sentry data model, not a specific @sentry/* package

type severity = [#fatal | #error | #warning | #log | #info | #debug]

type breadcrumb = {
  category?: string,
  message?: string,
  level?: severity,
  data?: Dict.t<JSON.t>,
}

type eventHint = {originalException?: exn}

// Stacktrace frame shape (subset of Sentry's StackFrame)
type stacktraceFrame = {filename: option<string>}
type stacktrace = {frames: option<array<stacktraceFrame>>}
type exceptionValue = {stacktrace: option<stacktrace>}
type exceptionValues = {values: option<array<exceptionValue>>}

// Sentry event shape (subset of Sentry Event interface)
type sentryEvent = {@as("exception") exception_: option<exceptionValues>}

type scopeContext = {
  tags?: Dict.t<string>,
  extra?: Dict.t<JSON.t>,
  user?: {id?: string, email?: string, username?: string},
}

// Re-export transport type for convenience
type transport = Bindings__Sentry__Transport.t
