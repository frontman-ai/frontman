open Vitest

module ResponseBody = FrontmanClient__MCP__ResponseBody
module SSE = FrontmanClient__MCP__SSE
module WebStreams = FrontmanBindings.WebStreams

@new
external makeResponse: WebAPI.FileAPI.readableStream<Uint8Array.t> => WebAPI.FetchAPI.response =
  "Response"

let encode = value => WebStreams.makeTextEncoder()->WebStreams.encode(value)

let controlledStream = (~cancel=() => Promise.resolve()) => {
  let controller = ref(None)
  let cancelled = ref(false)
  let body = WebStreams.makeReadableStream({
    start: value => controller := Some(value),
    cancel: _reason => {
      cancelled := true
      cancel()
    },
  })
  (body, controller.contents->Option.getOrThrow, cancelled)
}

let terminal = `data: {"jsonrpc":"2.0","id":1,"result":{"resultType":"complete"}}\n\n`

let oneByteStream = source =>
  WebStreams.makeReadableStream({
    start: controller => {
      for index in 0 to source->String.length - 1 {
        controller->WebStreams.enqueue(encode(source->ResponseBody.charAt(index)))
      }
      controller->WebStreams.close
    },
  })

afterEach(() => Vi.useRealTimers()->ignore)

describe("MCP response lifecycle", _t => {
  testAsync("times JSON out only after 60,001 ms and releases its reader", async t => {
    Vi.useFakeTimers()->ignore
    let (body, _controller, cancelled) = controlledStream()
    let reading = ResponseBody.readText(makeResponse(body))

    let _ = await Vi.advanceTimersByTimeAsync(ResponseBody.idleTimeoutMs)
    t->expect(Vi.getTimerCount())->Expect.toBe(1)
    let _ = await Vi.advanceTimersByTimeAsync(1)

    t
    ->expect(await reading)
    ->Expect.toEqual(Error(ResponseBody.ReadFailed("MCP response timed out")))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("resets the JSON deadline for zero-length chunks", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, _) = controlledStream()
    let reading = ResponseBody.readText(makeResponse(body))

    let _ = await Vi.advanceTimersByTimeAsync(ResponseBody.idleTimeoutMs - 1)
    controller->WebStreams.enqueue(encode(""))
    let _ = await Vi.advanceTimersByTimeAsync(0)
    let _ = await Vi.advanceTimersByTimeAsync(ResponseBody.idleTimeoutMs)
    controller->WebStreams.enqueue(encode("{}"))
    controller->WebStreams.close

    t->expect(await reading)->Expect.toEqual(Ok("{}"))
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("reads 32,768 one-byte JSON chunks without quadratic accumulation", async t => {
    let source = "x"->String.repeat(32768)
    let body = oneByteStream(source)

    t->expect(await ResponseBody.readText(makeResponse(body)))->Expect.toEqual(Ok(source))
    t->expect(body.locked)->Expect.toBe(false)
  })

  testAsync("reads a terminal SSE frame split into 32,768 one-byte chunks", async t => {
    let source = `data: ${" "->String.repeat(
        32701,
      )}{"jsonrpc":"2.0","id":1,"result":{"resultType":"complete"}}\n\n`
    let body = oneByteStream(source)

    t->expect((await SSE.readStream(makeResponse(body)))->Result.isOk)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
  })

  testAsync("lets SSE activity at exactly 60,000 ms win", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, _) = controlledStream()
    let reading = SSE.readStream(makeResponse(body))

    let _ = await Vi.advanceTimersByTimeAsync(ResponseBody.idleTimeoutMs)
    controller->WebStreams.enqueue(encode(terminal))
    let _ = await Vi.advanceTimersByTimeAsync(0)

    t->expect((await reading)->Result.isOk)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("cancels an already-aborted SSE response without awaiting cancel", async t => {
    Vi.useFakeTimers()->ignore
    let cancellation = () => Promise.make((_resolve, _reject) => ())
    let (body, _controller, cancelled) = controlledStream(~cancel=cancellation)
    let controller = WebAPI.AbortController.make()
    controller->WebAPI.AbortController.abort

    let result = await SSE.readStream(makeResponse(body), ~signal=controller.signal)

    t->expect(result)->Expect.toEqual(Error("Request cancelled"))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("settles SSE cancellation once and ignores late bytes", async t => {
    Vi.useFakeTimers()->ignore
    let (body, _controller, cancelled) = controlledStream()
    let abortController = WebAPI.AbortController.make()
    let notifications = ref(0)
    let reading = SSE.readStream(
      makeResponse(body),
      ~signal=abortController.signal,
      ~onNotification=_json => notifications := notifications.contents + 1,
    )

    abortController->WebAPI.AbortController.abort
    let result = await reading
    let _ = await Vi.advanceTimersByTimeAsync(ResponseBody.idleTimeoutMs + 1)

    t->expect(result)->Expect.toEqual(Error("Request cancelled"))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(notifications.contents)->Expect.toBe(0)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
})
