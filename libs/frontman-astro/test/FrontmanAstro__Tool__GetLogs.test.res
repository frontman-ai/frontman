// Integration tests for get_logs via the full HTTP middleware stack.
//
// These tests exercise the complete production path:
//   LogCapture.initialize() patches process.stderr
//   → stderr write
//   → POST /frontman/tools/call { name: "get_logs", arguments: { level: "build" } }
//   → SSE response body
//   → assert the log entry is present
//
// This is the same path used in production. We use the Astro tool registry
// (which includes get_logs) and the core middleware (which handles /tools/call).
//
// Regression: before the fix, get_logs called with level:"build" would return
// zero results for Astro [ERROR] messages because only process.stdout was
// intercepted. process.stderr was not patched, so those messages never reached
// the buffer.

open Vitest

module Middleware = FrontmanAstro__Middleware
module LogCapture = FrontmanAiFrontmanCore.FrontmanCore__LogCapture
module Config = FrontmanAstro__Config

// The Config module crashes at load time if __PACKAGE_VERSION__ is undefined,
// but vitest.config.ts already defines it via `define`. We bypass Config
// entirely and build the middleware config directly, same as the core
// middleware tests do.
module CoreMiddlewareConfig = FrontmanAiFrontmanCore.FrontmanCore__MiddlewareConfig
module CoreMiddleware = FrontmanAiFrontmanCore.FrontmanCore__Middleware
module ToolRegistry = FrontmanAstro__ToolRegistry

// Reset the LogCapture singleton between tests so initialize() re-patches
// both streams and the buffer starts empty.
let resetLogCapture: unit => unit = %raw(`
  function() {
    globalThis.__FRONTMAN_CORE_CONSOLE_PATCHED__ = false;
    globalThis.__FRONTMAN_CORE_INSTANCE__ = undefined;
  }
`)

let writeToStderr: string => unit = %raw(`
  function(message) { process.stderr.write(message + "\n"); }
`)

// Build the middleware with the Astro tool registry (includes get_logs).
let makeMiddleware = () => {
  let config: CoreMiddlewareConfig.t = {
    projectRoot: "/tmp",
    sourceRoot: "/tmp",
    basePath: "frontman",
    serverName: "test-server",
    serverVersion: "1.0.0",
    clientUrl: "http://localhost/client.js",
    clientCssUrl: None,
    entrypointUrl: None,
    isLightTheme: false,
    frameworkId: CoreMiddlewareConfig.Astro,
  }
  let registry = ToolRegistry.make()
  CoreMiddleware.createMiddleware(~config, ~registry)
}

// POST /frontman/tools/call with a JSON body and return the full SSE response text.
let callTool = async (middleware, ~name: string, ~arguments: JSON.t): string => {
  let body = JSON.Encode.object(
    Dict.fromArray([
      ("name", JSON.Encode.string(name)),
      ("arguments", arguments),
    ]),
  )
  let headers = WebAPI.HeadersInit.fromDict(
    Dict.fromArray([("Content-Type", "application/json")]),
  )
  let req = WebAPI.Request.fromURL(
    "http://localhost/frontman/tools/call",
    ~init={
      method: "POST",
      body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
      headers,
    },
  )
  let result = await middleware(req)
  switch result {
  | None => failwith("Middleware did not handle /frontman/tools/call")
  | Some(response) => await response->WebAPI.Response.text
  }
}

describe("get_logs via HTTP middleware (integration)", _t => {
  testAsync(
    "stderr Astro [ERROR] messages are returned by get_logs through the tools/call endpoint",
    async t => {
      resetLogCapture()
      LogCapture.initialize()

      writeToStderr(`18:16:48 [ERROR] Unable to locate "viewfinder-circle" icon!`)

      let middleware = makeMiddleware()
      let sseBody = await callTool(
        middleware,
        ~name="get_logs",
        ~arguments=JSON.Encode.object(
          Dict.fromArray([("level", JSON.Encode.string("build"))]),
        ),
      )

      // SSE body should contain an event with the log entry in the data payload
      t->expect(sseBody->String.includes("viewfinder-circle"))->Expect.toBe(true)
    },
  )

  testAsync("get_logs with level:build returns nothing when stderr was not initialized", async t => {
    // Skip initialize() — stderr is not patched, writes go nowhere
    resetLogCapture()

    writeToStderr(`18:16:48 [ERROR] Unable to locate "some-other-icon" icon!`)

    let middleware = makeMiddleware()
    let sseBody = await callTool(
      middleware,
      ~name="get_logs",
      ~arguments=JSON.Encode.object(
        Dict.fromArray([("level", JSON.Encode.string("build"))]),
      ),
    )

    t->expect(sseBody->String.includes("some-other-icon"))->Expect.toBe(false)
  })

  testAsync("get_logs is listed in the tools endpoint", async t => {
    let middleware = makeMiddleware()
    let req = WebAPI.Request.fromURL("http://localhost/frontman/tools")
    let result = await middleware(req)

    switch result {
    | None => failwith("Middleware did not handle /frontman/tools")
    | Some(response) =>
      let body = await response->WebAPI.Response.text
      t->expect(body->String.includes("get_logs"))->Expect.toBe(true)
    }
  })
})
