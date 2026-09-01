open Vitest

module RemoteSchema = FrontmanClient__MCP__RemoteSchema
module RemoteSchemaEngine = FrontmanClient__MCP__RemoteSchemaEngine

let json = value => JSON.parseOrThrow(value)

type counters = {mutable posted: int, mutable terminated: int}
type bundle = {files: array<string>, worker: string}

@module("./FrontmanClient__MCP__RemoteSchemaWorkerTest.mjs")
external makeControlledWorker: (int, RemoteSchema.response, counters) => RemoteSchema.worker =
  "makeControlledWorker"

@module("./FrontmanClient__MCP__RemoteSchemaWorkerTest.mjs")
external makeThrowingWorker: counters => RemoteSchema.worker = "makeThrowingWorker"

@module("./FrontmanClient__MCP__RemoteSchemaBundleTest.mjs")
external buildWorkerConsumer: unit => promise<bundle> = "buildWorkerConsumer"

afterEach(() => Vi.useRealTimers()->ignore)

describe("remote MCP tool schemas", _t => {
  testAsync("accepts supported dialects and validates values", async t => {
    let schema = json(`{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}`)
    t->expect((await RemoteSchema.compileSchema(~schema))->Result.isOk)->Expect.toBe(true)
    t
    ->expect((await RemoteSchema.validateValue(~schema, ~value=json(`{"path":"a"}`)))->Result.isOk)
    ->Expect.toBe(true)
    t
    ->expect((await RemoteSchema.validateValue(~schema, ~value=json(`{}`)))->Result.isError)
    ->Expect.toBe(true)
  })

  testAsync("rejects unsupported dialects and unresolved network refs", async t => {
    t
    ->expect(
      (
        await RemoteSchema.compileSchema(
          ~schema=json(`{"$schema":"https://example.com/schema","type":"object"}`),
        )
      )->Result.isError,
    )
    ->Expect.toBe(true)
    t
    ->expect(
      (
        await RemoteSchema.compileSchema(
          ~schema=json(`{"type":"object","properties":{"x":{"$ref":"https://example.com/x"}}}`),
        )
      )->Result.isError,
    )
    ->Expect.toBe(true)
  })

  testAsync("bounds schema traversal", async t => {
    let limits: RemoteSchema.limits = {maxDepth: 1, maxSubschemas: 10}
    t
    ->expect(
      (
        await RemoteSchema.compileSchema(
          ~schema=json(`{"type":"object","properties":{"x":{"type":"object"}}}`),
          ~limits,
        )
      )->Result.isError,
    )
    ->Expect.toBe(true)
  })

  testAsync("accepts 1,024 schema containers and rejects 1,025", async t => {
    let schemaWithChildren = count => {
      let properties = Dict.make()
      for index in 1 to count {
        properties->Dict.set(Int.toString(index), json(`{"type":"string"}`))
      }
      JSON.Encode.object(
        Dict.fromArray([
          ("type", JSON.Encode.string("object")),
          ("properties", JSON.Encode.object(properties)),
        ]),
      )
    }
    let limits: RemoteSchema.limits = {maxDepth: 32, maxSubschemas: 1024}

    t
    ->expect(
      RemoteSchemaEngine.compileSchema(~schema=schemaWithChildren(1022), ~limits)->Result.isOk,
    )
    ->Expect.toBe(true)
    t
    ->expect(
      RemoteSchemaEngine.compileSchema(~schema=schemaWithChildren(1023), ~limits)->Result.isError,
    )
    ->Expect.toBe(true)
  })

  testAsync("accepts completion at 100 ms and terminates the worker", async t => {
    Vi.useFakeTimers()->ignore
    let counters = {posted: 0, terminated: 0}
    let pending = RemoteSchema.run(
      ~schema=json(`{"type":"string"}`),
      ~operation="compile",
      ~value=json(`null`),
      ~limits=RemoteSchema.defaultLimits,
      ~signal=None,
      ~makeWorker=() => makeControlledWorker(100, {ok: true, error: None}, counters),
    )

    let _ = await Vi.advanceTimersByTimeAsync(100)

    t->expect(await pending)->Expect.toEqual(Ok())
    t->expect(counters.posted)->Expect.toBe(1)
    t->expect(counters.terminated)->Expect.toBe(1)
  })

  testAsync("terminates validation at 101 ms and ignores the late result", async t => {
    Vi.useFakeTimers()->ignore
    let counters = {posted: 0, terminated: 0}
    let pending = RemoteSchema.run(
      ~schema=json(`{"type":"string"}`),
      ~operation="compile",
      ~value=json(`null`),
      ~limits=RemoteSchema.defaultLimits,
      ~signal=None,
      ~makeWorker=() => makeControlledWorker(101, {ok: true, error: None}, counters),
    )

    let _ = await Vi.advanceTimersByTimeAsync(101)

    t->expect(await pending)->Expect.toEqual(Error(RemoteSchema.TimedOut))
    t->expect(counters.posted)->Expect.toBe(1)
    t->expect(counters.terminated)->Expect.toBe(1)
  })

  testAsync("cancellation terminates validation and removes ownership", async t => {
    Vi.useFakeTimers()->ignore
    let counters = {posted: 0, terminated: 0}
    let controller = WebAPI.AbortController.make()
    let pending = RemoteSchema.run(
      ~schema=json(`{"type":"string"}`),
      ~operation="validate",
      ~value=json(`"value"`),
      ~limits=RemoteSchema.defaultLimits,
      ~signal=Some(controller.signal),
      ~makeWorker=() => makeControlledWorker(100, {ok: true, error: None}, counters),
    )

    controller->WebAPI.AbortController.abort

    t->expect(await pending)->Expect.toEqual(Error(RemoteSchema.Cancelled))
    t->expect(counters.posted)->Expect.toBe(1)
    t->expect(counters.terminated)->Expect.toBe(1)
    let _ = await Vi.advanceTimersByTimeAsync(101)
    t->expect(counters.terminated)->Expect.toBe(1)
  })

  testAsync("post failure terminates the worker and returns a typed error", async t => {
    let counters = {posted: 0, terminated: 0}
    let result = await RemoteSchema.run(
      ~schema=json(`{"type":"string"}`),
      ~operation="compile",
      ~value=json(`null`),
      ~limits=RemoteSchema.defaultLimits,
      ~signal=None,
      ~makeWorker=() => makeThrowingWorker(counters),
    )

    switch result {
    | Error(RemoteSchema.WorkerFailed(_)) => t->expect(true)->Expect.toBe(true)
    | Ok() | Error(Invalid(_) | TimedOut | Cancelled) => t->expect(false)->Expect.toBe(true)
    }
    t->expect(counters.posted)->Expect.toBe(1)
    t->expect(counters.terminated)->Expect.toBe(1)
  })

  testAsync("worker construction failure returns a typed error", async t => {
    let result = await RemoteSchema.run(
      ~schema=json(`{"type":"string"}`),
      ~operation="compile",
      ~value=json(`null`),
      ~limits=RemoteSchema.defaultLimits,
      ~signal=None,
      ~makeWorker=() => JsError.throwWithMessage("construction failed"),
    )

    switch result {
    | Error(RemoteSchema.WorkerFailed(_)) => t->expect(true)->Expect.toBe(true)
    | Ok() | Error(Invalid(_) | TimedOut | Cancelled) => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("pathological validation cannot block the main thread", async t => {
    let schema = json(`{"type":"string","pattern":"^(a+)+$"}`)
    let value = json(`"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!"`)
    let mainThreadAdvanced = ref(false)
    setTimeout(() => mainThreadAdvanced := true, 0)->ignore

    let result = await RemoteSchema.validateValue(~schema, ~value)

    t->expect(result)->Expect.toEqual(Error(RemoteSchema.TimedOut))
    t->expect(mainThreadAdvanced.contents)->Expect.toBe(true)
  })

  testAsync("bundles the module worker and its AJV engine for a browser consumer", async t => {
    let bundle = await buildWorkerConsumer()
    t->expect(bundle.files->Array.length > 1)->Expect.toBe(true)
    t->expect(bundle.worker->String.includes("onmessage"))->Expect.toBe(true)
    t->expect(bundle.worker->String.includes("Unsupported JSON Schema dialect"))->Expect.toBe(true)
  })
})
