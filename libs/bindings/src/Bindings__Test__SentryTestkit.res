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
  reports: unit => array<report>,
  reset: unit => unit,
  isExist: string => bool,
  getExceptionAt: int => Nullable.t<exceptionInfo>,
  findReport: string => Nullable.t<report>,
}

type transport = Sentry__Transport.t

type testkitResult = {
  testkit: testkit,
  sentryTransport: transport,
}

@module("sentry-testkit") external make: unit => testkitResult = "default"

let getTransport = (result: testkitResult): transport => result.sentryTransport

let getTestkit = (result: testkitResult): testkit => result.testkit

let setup = () => {
  let result = make()
  (result.testkit, result.sentryTransport)
}
