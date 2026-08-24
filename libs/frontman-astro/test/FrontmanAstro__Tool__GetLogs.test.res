open Vitest

module Helpers = FrontmanAstro__TestHelpers
module LogCapture = FrontmanAiFrontmanCore.FrontmanCore__LogCapture
module ToolRegistry = FrontmanAstro__ToolRegistry

let resetLogCapture: unit => unit = %raw(`
  function() {
    globalThis.__FRONTMAN_CORE_CONSOLE_PATCHED__ = false;
    globalThis.__FRONTMAN_CORE_INSTANCE__ = undefined;
  }
`)

let writeToStderr: string => unit = %raw(`
  function(message) { process.stderr.write(message + "\n"); }
`)

let makeMiddleware = () => Helpers.makeMiddleware(~registry=ToolRegistry.make())

describe("get_logs via HTTP middleware (integration)", _t => {
  testAsync(
    "stderr Astro [ERROR] messages are returned by get_logs through the tools/call endpoint",
    async t => {
      resetLogCapture()
      LogCapture.initialize()

      writeToStderr(`18:16:48 [ERROR] Unable to locate "viewfinder-circle" icon!`)

      let middleware = makeMiddleware()
      let sseBody = await Helpers.callTool(
        middleware,
        ~name="get_logs",
        ~arguments=JSON.Encode.object(Dict.fromArray([("level", JSON.Encode.string("build"))])),
      )

      t->expect(sseBody->String.includes("viewfinder-circle"))->Expect.toBe(true)
    },
  )

  testAsync(
    "get_logs with level:build returns nothing when stderr was not initialized",
    async t => {
      resetLogCapture()

      writeToStderr(`18:16:48 [ERROR] Unable to locate "some-other-icon" icon!`)

      let middleware = makeMiddleware()
      let sseBody = await Helpers.callTool(
        middleware,
        ~name="get_logs",
        ~arguments=JSON.Encode.object(Dict.fromArray([("level", JSON.Encode.string("build"))])),
      )

      t->expect(sseBody->String.includes("some-other-icon"))->Expect.toBe(false)
    },
  )

  testAsync("get_logs is listed in the tools endpoint", async t => {
    let middleware = makeMiddleware()
    let body = await Helpers.getEndpoint(middleware, ~path="tools")
    t->expect(body->String.includes("get_logs"))->Expect.toBe(true)
  })
})
