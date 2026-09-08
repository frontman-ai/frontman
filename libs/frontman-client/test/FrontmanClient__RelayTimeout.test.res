open Vitest

module Relay = FrontmanClient__Relay

type fetchOptions = {signal: WebAPI.EventTypes.abortSignal}
type streamController
@module("vitest") @scope("vi")
external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi")
external unstubAllGlobals: unit => unit = "unstubAllGlobals"
@module("vitest") @scope("vi")
external timerCount: unit => int = "getTimerCount"
@send
external onAbort: (WebAPI.EventTypes.abortSignal, @as("abort") _, unit => unit) => unit =
  "addEventListener"
@new external makeError: string => exn = "Error"
type streamSource = {start: streamController => unit}
@new external makeStream: streamSource => WebAPI.ReadableStream.t<string> = "ReadableStream"
@send external failStream: (streamController, exn) => unit = "error"
@new external responseWithStream: WebAPI.ReadableStream.t<string> => WebAPI.Response.t = "Response"
@new external responseWithText: string => WebAPI.Response.t = "Response"

let connected = () => {
  let relay = Relay.make(~baseUrl="https://example.test")
  relay.state := Relay.Connected({tools: [], serverInfo: {name: "test", version: "1"}})
  relay
}

afterEach(() => {
  unstubAllGlobals()
  Vi.useRealTimers()->ignore
})

testAsync("aborts stalled fetch and warns that mutations may still run", async t => {
  Vi.useFakeTimers()->ignore
  stubGlobal("fetch", (_url: string, options: fetchOptions) =>
    Promise.make(
      (_resolve, reject) => {
        options.signal->onAbort(() => reject(makeError("aborted")))
      },
    )
  )
  let pending = connected()->Relay.executeTool(~name="wp_elementor_update_element", ~timeoutMs=10)
  let _ = await Vi.advanceTimersByTimeAsync(10)
  let result = await pending
  let message = switch result {
  | Error(message) => message
  | Ok(_) => failwith("Expected timeout")
  }
  t->expect(message->String.includes("during fetch"))->Expect.toBe(true)
  t->expect(message->String.includes("server may still be executing"))->Expect.toBe(true)
  t->expect(timerCount())->Expect.toBe(0)
})

testAsync("timeout also covers a stalled response body", async t => {
  Vi.useFakeTimers()->ignore
  stubGlobal("fetch", async (_url: string, options: fetchOptions) => {
    responseWithStream(
      makeStream({
        start: controller =>
          options.signal->onAbort(() => controller->failStream(makeError("aborted"))),
      }),
    )
  })
  let pending = connected()->Relay.executeTool(~name="wp_elementor_get_element", ~timeoutMs=10)
  let _ = await Vi.advanceTimersByTimeAsync(10)
  let result = await pending
  let message = switch result {
  | Error(message) => message
  | Ok(_) => failwith("Expected timeout")
  }
  t->expect(message->String.includes("during response read"))->Expect.toBe(true)
  t->expect(timerCount())->Expect.toBe(0)
})

testAsync("successful results clear the deadline", async t => {
  Vi.useFakeTimers()->ignore
  stubGlobal("fetch", async (_url: string, _options: fetchOptions) =>
    responseWithText("event: result\ndata: {\"content\":[]}\n\n")
  )
  let result = await connected()->Relay.executeTool(~name="wp_elementor_get_element", ~timeoutMs=10)
  t->expect(result->Result.isOk)->Expect.toBe(true)
  t->expect(timerCount())->Expect.toBe(0)
})
