open Vitest

module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module Chassis = FrontmanCore__NodeWebChassis

@module("node:stream") @scope("Readable")
external readableFrom: array<Uint8Array.t> => NodeHttp.incomingMessage = "from"

@module("node:stream") @scope("Readable")
external readableFromSource: unknown => NodeHttp.incomingMessage = "from"

@new external bytes: array<int> => Uint8Array.t = "Uint8Array"

@set external setMethod: (NodeHttp.incomingMessage, string) => unit = "method"
@set external setUrl: (NodeHttp.incomingMessage, string) => unit = "url"
@set external setHeaders: (NodeHttp.incomingMessage, Dict.t<string>) => unit = "headers"
@set external setRawHeaders: (NodeHttp.incomingMessage, array<string>) => unit = "rawHeaders"

@send external emitEvent: ('target, string) => bool = "emit"
@send external listenerCount: ('target, string) => int = "listenerCount"

type trackedSource = {
  source: unknown,
  readCount: unit => int,
}

let makeTrackedSource: unit => trackedSource = %raw(`
  function() {
    let reads = 0;
    const source = {
      async *[Symbol.asyncIterator]() {
        reads += 1;
        yield new Uint8Array([123, 125]);
      }
    };
    return {source, readCount() { return reads; }};
  }
`)

type trackedResponse = {
  response: NodeHttp.serverResponse,
  emit: string => unit,
  endCount: unit => int,
  statusCode: unit => int,
  writtenBytes: unit => array<int>,
  listenerCount: string => int,
  written: promise<unit>,
}

let makeTrackedResponseWithBackpressure: bool => trackedResponse = %raw(`
  function(backpressured) {
    const listeners = new Map();
    const writes = [];
    let ends = 0;
    let resolveWritten;
    const written = new Promise(resolve => { resolveWritten = resolve; });
    const response = {
      headersSent: false,
      statusCode: 0,
      on(event, listener) {
        const eventListeners = listeners.get(event) || [];
        eventListeners.push(listener);
        listeners.set(event, eventListeners);
      },
      once(event, listener) {
        const onceListener = () => {
          this.removeListener(event, onceListener);
          listener();
        };
        this.on(event, onceListener);
      },
      removeListener(event, listener) {
        const eventListeners = listeners.get(event) || [];
        listeners.set(event, eventListeners.filter(candidate => candidate !== listener));
      },
      setHeader() {},
      write(value) {
        writes.push(...value);
        resolveWritten();
        return !backpressured;
      },
      end() {
        ends += 1;
        for (const listener of [...(listeners.get("close") || [])]) listener();
      }
    };
    return {
      response,
      emit(event) {
        for (const listener of [...(listeners.get(event) || [])]) listener();
      },
      endCount() { return ends; },
      statusCode() { return response.statusCode; },
      writtenBytes() { return writes; },
      listenerCount(event) { return (listeners.get(event) || []).length; },
      written
    };
  }
`)

let makeTrackedResponse = () => makeTrackedResponseWithBackpressure(false)
let makeResponse = () => makeTrackedResponse().response

let makeRequest = () => {
  let request = readableFrom([WebStreams.makeTextEncoder()->WebStreams.encode("{}")])
  request->setMethod("POST")
  request->setUrl("/adapter-test")
  request->setHeaders(Dict.fromArray([("host", "localhost")]))
  request->setRawHeaders(["Host", "localhost", "Mcp-Param-Value", "a, b"])
  request
}

let prepareRequest = (request: NodeHttp.incomingMessage) => {
  request->setMethod("POST")
  request->setUrl("/adapter-test")
  request->setHeaders(Dict.fromArray([("host", "localhost")]))
  request->setRawHeaders(["Host", "localhost"])
  request
}

describe("shared Node/Web chassis", _t => {
  afterEach(() => Vi.useRealTimers()->ignore)

  testAsync("streams an untouched request with physical header evidence", async t => {
    let received: ref<option<Chassis.adaptedRequest<unit>>> = ref(None)
    let outcome = await Chassis.handle(
      ~nodeRequest=makeRequest(),
      ~nodeResponse=makeResponse(),
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=adapted => {
        received.contents = Some(adapted)
        Promise.resolve(None)
      },
    )

    let adapted = received.contents->Option.getOrThrow
    t->expect(outcome == Chassis.Passed)->Expect.toBe(true)
    t->expect(adapted.request.bodyUsed)->Expect.toBe(false)
    t->expect(adapted.signal.aborted)->Expect.toBe(false)
    t
    ->expect(adapted.rawHeaders->Array.map(field => (field.name, field.value)))
    ->Expect.toEqual([("Host", "localhost"), ("Mcp-Param-Value", "a, b")])
    t->expect(await adapted.request->WebAPI.Request.text)->Expect.toBe("{}")
  })

  testAsync("disconnect returns without waiting for an uncooperative gate", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let rejectGate = ref(None)
    let gate: promise<Chassis.gateResult<unit>> = Promise.make(
      (_resolve, reject) => rejectGate := Some(reject),
    )
    let handling = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => gate,
      ~dispatch=_adapted => failwith("Cancelled gate reached dispatch"),
    )

    response.emit("close")
    t->expect((await handling) == Chassis.Cancelled)->Expect.toBe(true)
    (rejectGate.contents->Option.getOrThrow)(Failure("late gate rejection"))
    await Promise.resolve()
    t->expect(response.endCount())->Expect.toBe(0)
    t->expect(request->listenerCount("aborted"))->Expect.toBe(0)
    t->expect(response.listenerCount("close"))->Expect.toBe(0)
  })

  testAsync("denies before constructing or pulling the Node body", async t => {
    let tracked = makeTrackedSource()
    let request = readableFromSource(tracked.source)->prepareRequest
    let response = makeTrackedResponse()
    let dispatched = ref(false)

    let outcome = await Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) =>
        Promise.resolve(Chassis.Denied(WebAPI.Response.fromNull(~init={status: 403}))),
      ~dispatch=_adapted => {
        dispatched := true
        Promise.resolve(None)
      },
    )

    t->expect(outcome == Chassis.Responded)->Expect.toBe(true)
    t->expect(tracked.readCount())->Expect.toBe(0)
    t->expect(dispatched.contents)->Expect.toBe(false)
    t->expect(response.endCount())->Expect.toBe(1)
  })

  testAsync("request abort owns one signal and suppresses a late response", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let received: ref<option<Chassis.adaptedRequest<unit>>> = ref(None)
    let resolveDispatch = ref(None)
    let dispatchPending = Promise.make((resolve, _reject) => resolveDispatch := Some(resolve))
    let resolveStarted = ref(None)
    let started = Promise.make((resolve, _reject) => resolveStarted := Some(resolve))
    let handle = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=adapted => {
        received := Some(adapted)
        (resolveStarted.contents->Option.getOrThrow)()
        dispatchPending
      },
    )

    await started
    request->emitEvent("aborted")->ignore
    let adapted: Chassis.adaptedRequest<unit> = received.contents->Option.getOrThrow
    t->expect(adapted.signal.aborted)->Expect.toBe(true)

    t->expect((await handle) == Chassis.Cancelled)->Expect.toBe(true)
    (resolveDispatch.contents->Option.getOrThrow)(Some(WebAPI.Response.fromString("late")))
    t->expect(response.writtenBytes())->Expect.toEqual([])
    t->expect(response.endCount())->Expect.toBe(0)
    t->expect(request->listenerCount("aborted"))->Expect.toBe(0)
    t->expect(response.listenerCount("close"))->Expect.toBe(0)
  })

  testAsync("request abort keeps cancellation when abort-aware dispatch rejects", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let startedResolver = ref(None)
    let started = Promise.make((resolve, _reject) => startedResolver := Some(resolve))
    let handling = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=adapted => {
        (startedResolver.contents->Option.getOrThrow)()
        Promise.make(
          (_resolve, reject) =>
            adapted.signal->WebAPI.AbortSignal.addEventListener(
              Abort,
              _event => reject(Failure("dispatch aborted")),
            ),
        )
      },
    )

    await started
    request->emitEvent("aborted")->ignore

    t->expect((await handling) == Chassis.Cancelled)->Expect.toBe(true)
    t->expect(response.endCount())->Expect.toBe(0)
  })

  testAsync("response close cancels an open response reader and writes no ending", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let cancelCount = ref(0)
    let stream = WebStreams.makeReadableStream({
      start: controller => controller->WebStreams.enqueue(bytes([0, 255, 1])),
      cancel: _reason => {
        cancelCount.contents = cancelCount.contents + 1
        Promise.resolve()
      },
    })
    let webResponse = WebAPI.Response.fromReadableStream(stream)
    let handle = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(webResponse)),
    )

    await response.written
    response.emit("close")

    t->expect((await handle) == Chassis.Cancelled)->Expect.toBe(true)
    t->expect(cancelCount.contents)->Expect.toBe(1)
    t->expect(response.writtenBytes())->Expect.toEqual([0, 255, 1])
    t->expect(response.endCount())->Expect.toBe(0)
    t->expect(request->listenerCount("aborted"))->Expect.toBe(0)
    t->expect(response.listenerCount("close"))->Expect.toBe(0)
  })

  testAsync("disconnect does not await a nonsettling reader cancellation", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let stream = WebStreams.makeReadableStream({
      start: controller => controller->WebStreams.enqueue(bytes([7, 8, 9])),
      cancel: _reason => Promise.make((_resolve, _reject) => ()),
    })
    let handling = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(WebAPI.Response.fromReadableStream(stream))),
    )

    await response.written
    response.emit("close")

    t->expect((await handling) == Chassis.Cancelled)->Expect.toBe(true)
    t->expect(response.endCount())->Expect.toBe(0)
  })

  testAsync("streams exact response bytes and removes lifecycle listeners", async t => {
    let request = makeRequest()
    let response = makeTrackedResponse()
    let webResponse = WebAPI.Response.fromTypedArray(bytes([0, 255, 195, 40]))

    let outcome = await Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(webResponse)),
    )

    t->expect(outcome == Chassis.Responded)->Expect.toBe(true)
    t->expect(response.writtenBytes())->Expect.toEqual([0, 255, 195, 40])
    t->expect(response.endCount())->Expect.toBe(1)
    t->expect(request->listenerCount("aborted"))->Expect.toBe(0)
    t->expect(response.listenerCount("close"))->Expect.toBe(0)
  })

  testAsync("waits for Node response drain before completing", async t => {
    let request = makeRequest()
    let response = makeTrackedResponseWithBackpressure(true)
    let handle = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(WebAPI.Response.fromTypedArray(bytes([1, 2, 3])))),
    )

    await response.written
    t->expect(response.writtenBytes())->Expect.toEqual([1, 2, 3])
    t->expect(response.endCount())->Expect.toBe(0)
    response.emit("drain")

    t->expect((await handle) == Chassis.Responded)->Expect.toBe(true)
    t->expect(response.endCount())->Expect.toBe(1)
    t->expect(response.listenerCount("drain"))->Expect.toBe(0)
  })

  testAsync("response close wins while waiting for Node drain", async t => {
    let request = makeRequest()
    let response = makeTrackedResponseWithBackpressure(true)
    let handle = Chassis.handle(
      ~nodeRequest=request,
      ~nodeResponse=response.response,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(WebAPI.Response.fromTypedArray(bytes([4, 5, 6])))),
    )

    await response.written
    response.emit("close")

    t->expect((await handle) == Chassis.Cancelled)->Expect.toBe(true)
    t->expect(response.endCount())->Expect.toBe(0)
    t->expect(response.listenerCount("drain"))->Expect.toBe(0)
  })

  testAsync(
    "aborts pending work and returns one empty 408 after the absolute deadline",
    async t => {
      Vi.useFakeTimers()->ignore
      let request = makeRequest()
      let response = makeTrackedResponse()
      let received = ref(None)
      let resolveDispatch = ref(None)
      let dispatchPending = Promise.make((resolve, _reject) => resolveDispatch := Some(resolve))
      let handling = Chassis.handle(
        ~nodeRequest=request,
        ~nodeResponse=response.response,
        ~absoluteTimeoutMs=600000,
        ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
        ~dispatch=adapted => {
          received := Some(adapted)
          dispatchPending
        },
      )

      let _ = await Vi.advanceTimersByTimeAsync(600000)
      t->expect(Vi.getTimerCount())->Expect.toBe(1)
      let _ = await Vi.advanceTimersByTimeAsync(1)

      t->expect((await handling) == Chassis.TimedOut)->Expect.toBe(true)
      let adapted: Chassis.adaptedRequest<unit> = received.contents->Option.getOrThrow
      t->expect(adapted.signal.aborted)->Expect.toBe(true)
      t->expect(response.statusCode())->Expect.toBe(408)
      t->expect(response.writtenBytes())->Expect.toEqual([])
      t->expect(response.endCount())->Expect.toBe(1)
      t->expect(Vi.getTimerCount())->Expect.toBe(0)

      (resolveDispatch.contents->Option.getOrThrow)(Some(WebAPI.Response.fromString("late")))
      await Promise.resolve()
      t->expect(response.writtenBytes())->Expect.toEqual([])
      t->expect(response.endCount())->Expect.toBe(1)
    },
  )

  testAsync("keeps the timeout when abort-aware dispatch rejects", async t => {
    Vi.useFakeTimers()->ignore
    let response = makeTrackedResponse()
    let handling = Chassis.handle(
      ~nodeRequest=makeRequest(),
      ~nodeResponse=response.response,
      ~absoluteTimeoutMs=600000,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=adapted =>
        Promise.make(
          (_resolve, reject) =>
            adapted.signal->WebAPI.AbortSignal.addEventListener(
              Abort,
              _event => reject(Failure("dispatch timed out")),
            ),
        ),
    )

    let _ = await Vi.advanceTimersByTimeAsync(600001)

    t->expect((await handling) == Chassis.TimedOut)->Expect.toBe(true)
    t->expect(response.statusCode())->Expect.toBe(408)
    t->expect(response.endCount())->Expect.toBe(1)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("lets a response committed exactly at the absolute deadline win", async t => {
    Vi.useFakeTimers()->ignore
    let response = makeTrackedResponse()
    let resolveDispatch = ref(None)
    let handling = Chassis.handle(
      ~nodeRequest=makeRequest(),
      ~nodeResponse=response.response,
      ~absoluteTimeoutMs=600000,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.make((resolve, _reject) => resolveDispatch := Some(resolve)),
    )

    let _ = await Vi.advanceTimersByTimeAsync(600000)
    (resolveDispatch.contents->Option.getOrThrow)(Some(WebAPI.Response.fromString("on time")))
    let _ = await Vi.advanceTimersByTimeAsync(0)

    t->expect((await handling) == Chassis.Responded)->Expect.toBe(true)
    t->expect(response.statusCode())->Expect.toBe(200)
    t->expect(response.endCount())->Expect.toBe(1)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("keeps the deadline armed while a response body has not emitted bytes", async t => {
    Vi.useFakeTimers()->ignore
    let response = makeTrackedResponse()
    let stream = WebStreams.makeReadableStream({start: _controller => ()})
    let handling = Chassis.handle(
      ~nodeRequest=makeRequest(),
      ~nodeResponse=response.response,
      ~absoluteTimeoutMs=600000,
      ~gate=(_headers, _rawHeaders) => Promise.resolve(Chassis.Granted()),
      ~dispatch=_adapted => Promise.resolve(Some(WebAPI.Response.fromReadableStream(stream))),
    )

    let _ = await Vi.advanceTimersByTimeAsync(600001)

    t->expect((await handling) == Chassis.TimedOut)->Expect.toBe(true)
    t->expect(response.statusCode())->Expect.toBe(408)
    t->expect(response.writtenBytes())->Expect.toEqual([])
    t->expect(response.endCount())->Expect.toBe(1)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
})
