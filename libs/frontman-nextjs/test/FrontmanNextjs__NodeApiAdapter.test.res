open Vitest

module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module NodeApiAdapter = FrontmanNextjs__NodeApiAdapter
module AdapterSecurity = FrontmanAiFrontmanCore.FrontmanCore__MCP__AdapterSecurity
module Core = FrontmanAiFrontmanCore
module Endpoint = Core.FrontmanCore__MCP__Endpoint
module HttpSecurity = Core.FrontmanCore__MCP__HttpSecurity
module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

@module("node:stream") @scope("Readable")
external readableFrom: array<Uint8Array.t> => NodeHttp.incomingMessage = "from"

type trackedRequest = {
  source: unknown,
  readCount: unit => int,
}

let makeTrackedSource: unit => trackedRequest = %raw(`
  function() {
    let reads = 0;
    const source = {
      async *[Symbol.asyncIterator]() {
        reads += 1;
        yield new Uint8Array([110, 111, 116, 32, 114, 101, 97, 100]);
      }
    };
    return {source, readCount: function() { return reads; }};
  }
`)

@module("node:stream") @scope("Readable")
external readableFromSource: unknown => NodeHttp.incomingMessage = "from"

@set external setMethod: (NodeHttp.incomingMessage, string) => unit = "method"
@set external setUrl: (NodeHttp.incomingMessage, string) => unit = "url"
@set external setHeaders: (NodeHttp.incomingMessage, Dict.t<string>) => unit = "headers"
@set external setRawHeaders: (NodeHttp.incomingMessage, array<string>) => unit = "rawHeaders"
@send external emitEvent: ('target, string) => bool = "emit"
@send external listenerCount: ('target, string) => int = "listenerCount"

let makeResponse: unit => NodeHttp.serverResponse = %raw(`
  function() {
    const listeners = new Map();
    return {
      headersSent: false,
      statusCode: 0,
      on(event, listener) {
        const eventListeners = listeners.get(event) || [];
        eventListeners.push(listener);
        listeners.set(event, eventListeners);
      },
      removeListener(event, listener) {
        const eventListeners = listeners.get(event) || [];
        listeners.set(event, eventListeners.filter(candidate => candidate !== listener));
      },
      emit(event) {
        for (const listener of [...(listeners.get(event) || [])]) listener();
        return true;
      },
      listenerCount(event) { return (listeners.get(event) || []).length; },
      setHeader() {},
      write() { return true; },
      end() {}
    };
  }
`)

let makeRequest = (~body="{}", ~rawHeaders) => {
  let bytes = WebStreams.makeTextEncoder()->WebStreams.encode(body)
  let request = readableFrom([bytes])
  request->setMethod("POST")
  request->setUrl("/api/frontman-mcp")
  request->setHeaders(Dict.fromArray([("host", "localhost:3000")]))
  request->setRawHeaders(rawHeaders)
  request
}

let security = () =>
  AdapterSecurity.make({
    allowedOrigins: ["https://client.example"],
    authorize: async _headers => #authorized,
  })

describe("Next.js Node API adapter", _t => {
  testAsync("preserves physical headers and streams the untouched request body", async t => {
    let nodeRequest = makeRequest(
      ~rawHeaders=[
        "Host",
        "localhost:3000",
        "Origin",
        "https://client.example",
        "Mcp-Param-Value",
        "a, b",
        "mcp-param-value",
        "second",
      ],
    )
    nodeRequest->setHeaders(
      Dict.fromArray([("host", "localhost:3000"), ("origin", "https://client.example")]),
    )
    let received = ref(None)
    let outcome = await NodeApiAdapter.handleRequest(
      nodeRequest,
      makeResponse(),
      ~security=security(),
      ~middleware=adapted => {
        received.contents = Some(adapted)
        Promise.resolve(None)
      },
    )
    let adapted = received.contents->Option.getOrThrow

    t->expect(outcome == NodeApiAdapter.Chassis.Passed)->Expect.toBe(true)
    t
    ->expect(adapted.rawHeaders->Array.map(field => (field.name, field.value)))
    ->Expect.toEqual([
      ("Host", "localhost:3000"),
      ("Origin", "https://client.example"),
      ("Mcp-Param-Value", "a, b"),
      ("mcp-param-value", "second"),
    ])
    t->expect(adapted.request.bodyUsed)->Expect.toBe(false)
    t->expect(await adapted.request->WebAPI.Request.text)->Expect.toBe("{}")
  })

  testAsync("crashes on malformed physical header evidence", async t => {
    let crashed = try {
      let _ = await NodeApiAdapter.handleRequest(
        makeRequest(~rawHeaders=["Mcp-Param-Value"]),
        makeResponse(),
        ~security=security(),
        ~middleware=_ => Promise.resolve(None),
      )
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("Node raw headers contained an unmatched field name")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  testAsync("does not pull the Node body before Origin rejection", async t => {
    let tracked = makeTrackedSource()
    let nodeRequest = readableFromSource(tracked.source)
    nodeRequest->setMethod("POST")
    nodeRequest->setUrl("/api/frontman-mcp")
    nodeRequest->setHeaders(
      Dict.fromArray([
        ("host", "localhost:3000"),
        ("origin", "https://evil.example"),
        ("content-type", "text/plain"),
      ]),
    )
    nodeRequest->setRawHeaders([
      "Host",
      "localhost:3000",
      "Origin",
      "https://evil.example",
      "Content-Type",
      "text/plain",
    ])

    t->expect(tracked.readCount())->Expect.toBe(0)
    let outcome = await NodeApiAdapter.handleRequest(
      nodeRequest,
      makeResponse(),
      ~security=security(),
      ~middleware=_ => failwith("Origin rejection reached middleware"),
    )
    t->expect(outcome == NodeApiAdapter.Chassis.Responded)->Expect.toBe(true)
    t->expect(tracked.readCount())->Expect.toBe(0)
  })

  testAsync("crashes when Next.js body parsing consumed the request", async t => {
    let nodeRequest = makeRequest(
      ~rawHeaders=["Origin", "https://client.example", "Host", "localhost:3000"],
    )
    let stream = nodeRequest->NodeHttp.Readable.toWeb
    let reader = stream->WebAPI.ReadableStream.getReader
    let _ = await WebStreams.readChunk(reader)

    let crashed = try {
      let _ = await NodeApiAdapter.handleRequest(
        nodeRequest,
        makeResponse(),
        ~security=security(),
        ~middleware=_ => Promise.resolve(None),
      )
      false
    } catch {
    | Failure(message) =>
      t
      ->expect(message)
      ->Expect.toBe("Node request body was consumed before streaming adaptation")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  testAsync("owns response-close cancellation and removes listeners", async t => {
    let nodeRequest = makeRequest(
      ~rawHeaders=["Host", "localhost:3000", "Origin", "https://client.example"],
    )
    nodeRequest->setHeaders(
      Dict.fromArray([("host", "localhost:3000"), ("origin", "https://client.example")]),
    )
    let response = makeResponse()
    let signal: ref<option<WebAPI.EventAPI.abortSignal>> = ref(None)
    let resolveMiddleware = ref(None)
    let pending = Promise.make((resolve, _reject) => resolveMiddleware := Some(resolve))
    let resolveStarted = ref(None)
    let started = Promise.make((resolve, _reject) => resolveStarted := Some(resolve))
    let handling = NodeApiAdapter.handleRequest(
      nodeRequest,
      response,
      ~security=security(),
      ~middleware=adapted => {
        signal := Some(adapted.signal)
        (resolveStarted.contents->Option.getOrThrow)()
        pending
      },
    )

    await started
    response->emitEvent("close")->ignore
    let cancellationSignal: WebAPI.EventAPI.abortSignal = signal.contents->Option.getOrThrow
    t->expect(cancellationSignal.aborted)->Expect.toBe(true)

    t->expect((await handling) == NodeApiAdapter.Chassis.Cancelled)->Expect.toBe(true)
    (resolveMiddleware.contents->Option.getOrThrow)(None)
    t->expect(nodeRequest->listenerCount("aborted"))->Expect.toBe(0)
    t->expect(response->listenerCount("close"))->Expect.toBe(0)
  })

  testAsync(
    "dispatches the active synchronous MCP endpoint with one authorization decision",
    async t => {
      let authorizationCount = ref(0)
      let config: Endpoint.config = {
        security: HttpSecurity.make(
          ~allowedOrigins=["https://client.example"],
          ~authorize=async _headers => {
            authorizationCount.contents = authorizationCount.contents + 1
            HttpSecurity.Authorized
          },
        ),
        registry: Core.FrontmanCore__ToolRegistry.make(),
        projectRoot: "/project",
        sourceRoot: "/project",
        serverName: "frontman-next-test",
        serverVersion: "1.0.0",
        allowedPreflightHeaders: [],
      }
      let body = `{"jsonrpc":"2.0","id":"discover","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}}}}`
      let request = makeRequest(
        ~body,
        ~rawHeaders=[
          "Host",
          "localhost:3000",
          "Origin",
          "https://client.example",
          "Content-Type",
          "application/json",
          "Accept",
          "application/json, text/event-stream",
          "MCP-Protocol-Version",
          MCP.protocolVersion,
          "Mcp-Method",
          "server/discover",
        ],
      )
      let outcome = await NodeApiAdapter.handleEndpoint(request, makeResponse(), ~config)

      t->expect(outcome == NodeApiAdapter.Chassis.Responded)->Expect.toBe(true)
      t->expect(authorizationCount.contents)->Expect.toBe(1)
    },
  )
})
