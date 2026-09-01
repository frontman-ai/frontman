open Vitest

module Bindings = FrontmanVite__Bindings
module Plugin = FrontmanVite__Plugin
module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module Core = FrontmanAiFrontmanCore
module Endpoint = Core.FrontmanCore__MCP__Endpoint
module HttpSecurity = Core.FrontmanCore__MCP__HttpSecurity

@module("node:stream") @scope("Readable")
external readableFrom: array<Uint8Array.t> => Bindings.incomingMessage = "from"

@set external setMethod: (Bindings.incomingMessage, string) => unit = "method"
@set external setUrl: (Bindings.incomingMessage, string) => unit = "url"
@set external setHeaders: (Bindings.incomingMessage, Dict.t<string>) => unit = "headers"
@set external setRawHeaders: (Bindings.incomingMessage, array<string>) => unit = "rawHeaders"

let makeIncomingMessage: array<string> => Bindings.incomingMessage = %raw(`
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

let makeServerResponse: unit => Bindings.serverResponse = %raw(`
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

let makeStreamingRequest = (~url, ~body) => {
  let request = readableFrom([WebStreams.makeTextEncoder()->WebStreams.encode(body)])
  request->setMethod("POST")
  request->setUrl(url)
  request->setHeaders(Dict.fromArray([("host", "localhost")]))
  request->setRawHeaders(["Host", "localhost"])
  request
}

describe("Vite Node adapter physical headers", _t => {
  testAsync("passes physical fields through the adapted middleware", async t => {
    let received = ref(None)
    let nextCount = ref(0)
    let middleware = (_request, ~rawHeaders) => {
      received.contents = Some(rawHeaders)
      Promise.resolve(None)
    }
    let adapted = Plugin.adaptMiddlewareToVite(~basePath="frontman", middleware)

    await adapted(
      makeIncomingMessage([
        "Host",
        "localhost",
        "Mcp-Param-Value",
        "a, b",
        "mcp-param-value",
        "second",
      ]),
      makeServerResponse(),
      () => nextCount.contents = nextCount.contents + 1,
    )

    t
    ->expect(
      received.contents
      ->Option.getOrThrow
      ->Array.map(field => (field.name, field.value)),
    )
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
    let middleware = (request: WebAPI.Request.t, ~rawHeaders) => {
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
    }
    let nextCount = ref(0)
    let adapted = Plugin.adaptMiddlewareToVite(~basePath="frontman", middleware)

    await adapted(
      makeStreamingRequest(~url="/frontman/resolve-source-location", ~body="streamed"),
      makeServerResponse(),
      () => nextCount.contents = nextCount.contents + 1,
    )

    t->expect(bodyUsedAtDispatch.contents)->Expect.toBe(false)
    t->expect(body.contents)->Expect.toBe("streamed")
    t->expect(nextCount.contents)->Expect.toBe(1)
  })

  testAsync("leaves the inactive MCP route unread", async t => {
    let middlewareCount = ref(0)
    let nextCount = ref(0)
    let request = makeStreamingRequest(~url="/mcp", ~body="must remain unread")
    let adapted = Plugin.adaptMiddlewareToVite(
      ~basePath="frontman",
      (_request, ~rawHeaders) => {
        rawHeaders->ignore
        middlewareCount.contents = middlewareCount.contents + 1
        Promise.resolve(None)
      },
    )

    await adapted(request, makeServerResponse(), () => nextCount.contents = nextCount.contents + 1)

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
      serverName: "frontman-vite-test",
      serverVersion: "1.0.0",
      allowedPreflightHeaders: [],
    }
    let middlewareCount = ref(0)
    let nextCount = ref(0)
    let adapted = Plugin.adaptMiddlewareToVite(
      ~basePath="frontman",
      ~mcp=Some(mcp),
      (_request, ~rawHeaders) => {
        rawHeaders->ignore
        middlewareCount.contents = middlewareCount.contents + 1
        Promise.resolve(None)
      },
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

    await adapted(request, makeServerResponse(), () => nextCount.contents = nextCount.contents + 1)

    t->expect(authorizationCount.contents)->Expect.toBe(1)
    t->expect(middlewareCount.contents)->Expect.toBe(0)
    t->expect(nextCount.contents)->Expect.toBe(0)
    t->expect(request->NodeHttp.readableDidRead)->Expect.toBe(true)
  })
})
