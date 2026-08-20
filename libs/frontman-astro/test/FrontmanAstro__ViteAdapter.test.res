open Vitest

module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module ViteAdapter = FrontmanAstro__ViteAdapter
module Core = FrontmanAiFrontmanCore
module Endpoint = Core.FrontmanCore__MCP__Endpoint
module HttpSecurity = Core.FrontmanCore__MCP__HttpSecurity

@module("node:stream") @scope("Readable")
external readableFrom: array<Uint8Array.t> => NodeHttp.incomingMessage = "from"

@set external setMethod: (NodeHttp.incomingMessage, string) => unit = "method"
@set external setUrl: (NodeHttp.incomingMessage, string) => unit = "url"
@set external setHeaders: (NodeHttp.incomingMessage, Dict.t<string>) => unit = "headers"
@set external setRawHeaders: (NodeHttp.incomingMessage, array<string>) => unit = "rawHeaders"
let makeIncomingRequest: array<string> => NodeHttp.incomingMessage = %raw(`
  function(rawHeaders) {
    const listeners = new Map();
    return {
      method: "GET",
      url: "/frontman/resolve-source-location",
      headers: {host: "localhost"},
      rawHeaders,
      readableDidRead: false,
      destroyed: false,
      on(event, listener) {
        const eventListeners = listeners.get(event) || [];
        eventListeners.push(listener);
        listeners.set(event, eventListeners);
      },
      removeListener(event, listener) {
        const eventListeners = listeners.get(event) || [];
        listeners.set(event, eventListeners.filter(candidate => candidate !== listener));
      },
      destroy() { this.destroyed = true; }
    };
  }
`)
let makeServerResponse: unit => NodeHttp.serverResponse = %raw(`
  function() {
    const listeners = new Map();
    return {
      headersSent: false,
      on(event, listener) {
        const eventListeners = listeners.get(event) || [];
        eventListeners.push(listener);
        listeners.set(event, eventListeners);
      },
      removeListener(event, listener) {
        const eventListeners = listeners.get(event) || [];
        listeners.set(event, eventListeners.filter(candidate => candidate !== listener));
      },
      setHeader() {},
      write() { return true; },
      end() {}
    };
  }
`)
type trackedResponse = {response: NodeHttp.serverResponse, ended: promise<unit>}
let makeTrackedResponse: unit => trackedResponse = %raw(`
  function() {
    const listeners = new Map();
    let resolveEnded;
    const ended = new Promise(resolve => { resolveEnded = resolve; });
    return {
      response: {
        headersSent: false,
        on(event, listener) {
          const eventListeners = listeners.get(event) || [];
          eventListeners.push(listener);
          listeners.set(event, eventListeners);
        },
        removeListener(event, listener) {
          const eventListeners = listeners.get(event) || [];
          listeners.set(event, eventListeners.filter(candidate => candidate !== listener));
        },
        setHeader() {},
        write() { return true; },
        end() { resolveEnded(); }
      },
      ended
    };
  }
`)

let makeStreamingRequest = (~url, ~body) => {
  let request = readableFrom([WebStreams.makeTextEncoder()->WebStreams.encode(body)])
  request->setMethod("POST")
  request->setUrl(url)
  request->setHeaders(Dict.fromArray([("host", "localhost")]))
  request->setRawHeaders(["Host", "localhost"])
  request
}

describe("Astro Node adapter physical headers", _t => {
  testAsync("passes physical fields through the adapted middleware", async t => {
    let nextCount = ref(0)
    let resolveReceived = ref(None)
    let received = Promise.make((resolve, _reject) => resolveReceived.contents = Some(resolve))
    let resolveNext = ref(None)
    let nextCalled = Promise.make((resolve, _reject) => resolveNext.contents = Some(resolve))
    let middleware = (_request, ~rawHeaders) => {
      let resolve = resolveReceived.contents->Option.getOrThrow
      resolve(rawHeaders)
      Promise.resolve(None)
    }
    let adapted = ViteAdapter.adaptToConnect(middleware, ~basePath="frontman")
    let request = makeIncomingRequest([
      "Host",
      "localhost",
      "Mcp-Param-Value",
      "a, b",
      "mcp-param-value",
      "second",
    ])

    adapted(
      request,
      makeServerResponse(),
      () => {
        nextCount.contents = nextCount.contents + 1
        (resolveNext.contents->Option.getOrThrow)()
      },
    )
    let fields = await received
    await nextCalled

    t
    ->expect(fields->Array.map(field => (field.name, field.value)))
    ->Expect.toEqual([
      ("Host", "localhost"),
      ("Mcp-Param-Value", "a, b"),
      ("mcp-param-value", "second"),
    ])
    t->expect(nextCount.contents)->Expect.toBe(1)
  })

  testAsync("streams a matched request without pre-buffering", async t => {
    let bodyUsedAtDispatch = ref(true)
    let body = ref("")
    let resolveNext = ref(None)
    let nextCalled = Promise.make((resolve, _reject) => resolveNext := Some(resolve))
    let adapted = ViteAdapter.adaptToConnect(
      (request: WebAPI.FetchAPI.request, ~rawHeaders) => {
        rawHeaders->ignore
        bodyUsedAtDispatch := request.bodyUsed
        request
        ->WebAPI.Request.text
        ->Promise.then(
          text => {
            body := text
            Promise.resolve(None)
          },
        )
      },
      ~basePath="frontman",
    )

    adapted(
      makeStreamingRequest(~url="/frontman/resolve-source-location", ~body="streamed"),
      makeServerResponse(),
      () => (resolveNext.contents->Option.getOrThrow)(),
    )
    await nextCalled

    t->expect(bodyUsedAtDispatch.contents)->Expect.toBe(false)
    t->expect(body.contents)->Expect.toBe("streamed")
  })

  testAsync("leaves the inactive MCP route unread", async t => {
    let middlewareCount = ref(0)
    let nextCount = ref(0)
    let request = makeStreamingRequest(~url="/mcp", ~body="must remain unread")
    let adapted = ViteAdapter.adaptToConnect(
      (_request, ~rawHeaders) => {
        rawHeaders->ignore
        middlewareCount.contents = middlewareCount.contents + 1
        Promise.resolve(None)
      },
      ~basePath="frontman",
    )

    adapted(request, makeServerResponse(), () => nextCount.contents = nextCount.contents + 1)

    t->expect(middlewareCount.contents)->Expect.toBe(0)
    t->expect(nextCount.contents)->Expect.toBe(1)
    t->expect(request->NodeHttp.readableDidRead)->Expect.toBe(false)
  })

  testAsync("activates the exact MCP route only with explicit security", async t => {
    let authorizationCount = ref(0)
    let mcp: Endpoint.config = {
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
      serverName: "frontman-astro-test",
      serverVersion: "1.0.0",
      allowedPreflightHeaders: [],
    }
    let middlewareCount = ref(0)
    let nextCount = ref(0)
    let adapted = ViteAdapter.adaptToConnect(
      (_request, ~rawHeaders) => {
        rawHeaders->ignore
        middlewareCount.contents = middlewareCount.contents + 1
        Promise.resolve(None)
      },
      ~basePath="frontman",
      ~mcp=Some(mcp),
    )
    let request = makeStreamingRequest(~url="/mcp", ~body="{}")
    request->setRawHeaders([
      "Host",
      "localhost",
      "Origin",
      "https://client.example",
      "Content-Type",
      "application/json",
      "Accept",
      "application/json, text/event-stream",
    ])
    let response = makeTrackedResponse()

    adapted(request, response.response, () => nextCount.contents = nextCount.contents + 1)
    await response.ended

    t->expect(authorizationCount.contents)->Expect.toBe(1)
    t->expect(middlewareCount.contents)->Expect.toBe(0)
    t->expect(nextCount.contents)->Expect.toBe(0)
    t->expect(request->NodeHttp.readableDidRead)->Expect.toBe(true)
  })
})
