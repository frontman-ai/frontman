// Bindings for sentry-testkit
// Used to capture and verify Sentry events in tests
// See: https://docs.sentry.io/platforms/javascript/configuration/sentry-testkit/

type breadcrumb = {
  category?: string,
  message?: string,
  level?: string,
}

type report = {
  message?: string,
  level?: string,
  tags?: Dict.t<string>,
  extra?: Dict.t<JSON.t>,
  breadcrumbs?: array<breadcrumb>,
}

type exceptionInfo = {message: string}

type testkit = {
  // Get all captured reports
  reports: unit => array<report>,
  // Reset all captured reports
  reset: unit => unit,
  // Check if a report with given message exists
  isExist: string => bool,
  // Get exception at index
  getExceptionAt: int => Nullable.t<exceptionInfo>,
  // Find report by message
  findReport: string => Nullable.t<report>,
}

type transport = Bindings__Sentry__Transport.t

type testkitResult = {
  testkit: testkit,
  sentryTransport: transport,
}

@module("sentry-testkit") external make: unit => testkitResult = "default"

// Helper to extract transport for Sentry.init
let getTransport = (result: testkitResult): transport => result.sentryTransport

// Helper to extract testkit for assertions
let getTestkit = (result: testkitResult): testkit => result.testkit

// Convenience: create and return both parts
let setup = () => {
  let result = make()
  (result.testkit, result.sentryTransport)
}
