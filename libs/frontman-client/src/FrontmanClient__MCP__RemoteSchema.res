module Engine = FrontmanClient__MCP__RemoteSchemaEngine

type limits = Engine.limits
type validationError =
  | Invalid(string)
  | TimedOut
  | Cancelled
  | WorkerFailed(string)

type request = {
  @live
  operation: string,
  @live
  schema: JSON.t,
  @live
  value: JSON.t,
  @live
  limits: limits,
}

type response = {ok: bool, error: option<string>, ready?: bool}
type messageEvent<'value> = {data: 'value}
type errorEvent = {message: string}
type timeoutId
type worker
type workerOptions = {@as("type") @live type_: string}
type blob
type blobOptions = {@as("type") @live type_: string}

let defaultLimits = Engine.defaultLimits
let validationTimeoutMs = 100
let workerStartupTimeoutMs = 10_000

let errorMessage = exn =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Schema worker failed")

@val external importMetaUrl: string = "import.meta.url"
@new external makeWorker: (WebAPI.UrlTypes.url, workerOptions) => worker = "Worker"
@new external makeBlob: (array<string>, blobOptions) => blob = "Blob"
@scope("URL") external createObjectUrl: blob => string = "createObjectURL"
@scope("URL") external revokeObjectUrl: string => unit = "revokeObjectURL"
@send external postMessage: (worker, request) => unit = "postMessage"
@send external terminate: worker => unit = "terminate"
@set external setOnMessage: (worker, messageEvent<response> => unit) => unit = "onmessage"
@set external setOnError: (worker, errorEvent => unit) => unit = "onerror"

@val external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"
@val external clearTimeout: timeoutId => unit = "clearTimeout"
@val @scope("performance") external monotonicNow: unit => float = "now"

let defaultMakeWorker = () => {
  let moduleUrl = WebAPI.URL.make(
    ~url="./FrontmanClient__MCP__RemoteSchemaWorker.res.mjs",
    ~base=importMetaUrl,
  )
  switch Js.typeof(WebAPI.Global.window) {
  | "undefined" =>
    makeWorker(
      WebAPI.URL.make(
        ~url="./FrontmanClient__MCP__RemoteSchemaWorker.res.mjs",
        ~base=importMetaUrl,
      ),
      {type_: "module"},
    )
  | _ if moduleUrl.origin == WebAPI.Global.location.origin =>
    makeWorker(moduleUrl, {type_: "module"})
  | _ =>
    let importSpecifier = JSON.stringify(JSON.Encode.string(moduleUrl.href))
    let blobUrl = createObjectUrl(
      makeBlob([`import(${importSpecifier})`], {type_: "text/javascript"}),
    )
    let worker = try {
      makeWorker(WebAPI.URL.make(~url=blobUrl), {type_: "module"})
    } catch {
    | exn =>
      revokeObjectUrl(blobUrl)
      throw(exn)
    }
    revokeObjectUrl(blobUrl)
    worker
  }
}

let run = async (
  ~schema,
  ~operation,
  ~value,
  ~limits,
  ~signal: option<WebAPI.EventAPI.abortSignal>,
  ~makeWorker=defaultMakeWorker,
): result<unit, validationError> => {
  switch signal->Option.mapOr(false, signal => signal.aborted) {
  | true => Error(Cancelled)
  | false =>
    let workerOwner = ref(None)
    let cleanupOwner = ref(None)
    try {
      let worker = makeWorker()
      workerOwner := Some(worker)
      let timeoutId = ref(None)
      let settled = ref(false)
      let abortListener = ref(None)
      let startedAt = ref(0.0)
      let cleanup = () => {
        timeoutId.contents->Option.forEach(clearTimeout)
        abortListener.contents->Option.forEach(listener =>
          signal->Option.forEach(signal =>
            signal->WebAPI.AbortSignal.removeEventListener(Abort, listener)
          )
        )
        worker->terminate
      }
      cleanupOwner := Some(cleanup)
      await Promise.make((resolve, _reject) => {
        let settle = result => {
          switch settled.contents {
          | true => ()
          | false =>
            settled := true
            cleanup()
            resolve(result)
          }
        }
        let onAbort = _event => settle(Error(Cancelled))
        abortListener := Some(onAbort)
        signal->Option.forEach(signal =>
          signal->WebAPI.AbortSignal.addEventListener(Abort, onAbort)
        )
        worker->setOnMessage(event => {
          switch event.data.ready {
          | Some(true) =>
            timeoutId.contents->Option.forEach(clearTimeout)
            startedAt := monotonicNow()
            timeoutId := Some(setTimeout(() => settle(Error(TimedOut)), validationTimeoutMs + 1))
            try {
              worker->postMessage({operation, schema, value, limits})
            } catch {
            | exn => settle(Error(WorkerFailed(errorMessage(exn))))
            }
          | Some(false) | None =>
            switch monotonicNow() -. startedAt.contents <= validationTimeoutMs->Int.toFloat {
            | false => settle(Error(TimedOut))
            | true =>
              switch event.data.ok {
              | true => settle(Ok())
              | false => settle(Error(Invalid(event.data.error->Option.getOrThrow)))
              }
            }
          }
        })
        worker->setOnError(event => settle(Error(WorkerFailed(event.message))))
        timeoutId :=
          Some(
            setTimeout(
              () => settle(Error(WorkerFailed("Schema worker startup timed out"))),
              workerStartupTimeoutMs,
            ),
          )
        switch signal->Option.mapOr(false, signal => signal.aborted) {
        | true => settle(Error(Cancelled))
        | false => ()
        }
      })
    } catch {
    | exn =>
      switch cleanupOwner.contents {
      | Some(cleanup) => cleanup()
      | None => workerOwner.contents->Option.forEach(terminate)
      }
      Error(WorkerFailed(errorMessage(exn)))
    }
  }
}

let compileSchema = async (
  ~schema,
  ~limits=defaultLimits,
  ~signal: option<WebAPI.EventAPI.abortSignal>=?,
): result<unit, validationError> =>
  await run(~schema, ~operation="compile", ~value=schema, ~limits, ~signal)

let validateValue = async (~schema, ~value, ~signal: option<WebAPI.EventAPI.abortSignal>=?): result<
  unit,
  validationError,
> => await run(~schema, ~operation="validate", ~value, ~limits=defaultLimits, ~signal)
