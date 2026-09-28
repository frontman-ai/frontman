type severity = [#fatal | #error | #warning | #log | #info | #debug]

type breadcrumb = {
  category?: string,
  message?: string,
  level?: severity,
  data?: Dict.t<JSON.t>,
}

type eventHint = {originalException?: exn}

type stacktraceFrame = {filename: option<string>}
type stacktrace = {frames: option<array<stacktraceFrame>>}
type exceptionValue = {stacktrace: option<stacktrace>}
type exceptionValues = {values: option<array<exceptionValue>>}

type sentryEvent = {@as("exception") exception_: option<exceptionValues>}

type scopeContext = {
  tags?: Dict.t<string>,
  extra?: Dict.t<JSON.t>,
  user?: {id?: string, email?: string, username?: string},
}

type transport = Sentry__Transport.t
