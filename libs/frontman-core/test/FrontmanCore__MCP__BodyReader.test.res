open Vitest

module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module BodyReader = FrontmanCore__MCP__BodyReader
module WebStreams = FrontmanBindings.WebStreams

exception StreamFailed

module Helpers = {
  let encode = value => WebStreams.makeTextEncoder()->WebStreams.encode(value)

  let headers = contentLength =>
    switch contentLength {
    | Some(value) => WebAPI.Headers.fromKeyValueArray([("Content-Length", value)])
    | None => WebAPI.Headers.make()
    }

  let stream = (~chunks, ~cancelled=ref(false), ~pulls=ref(0)) => {
    let index = ref(0)
    let body = WebStreams.makeReadableStream({
      pull: controller => {
        pulls.contents = pulls.contents + 1
        switch chunks->Array.get(index.contents) {
        | Some(chunk) =>
          index.contents = index.contents + 1
          controller->WebStreams.enqueue(chunk)
        | None => controller->WebStreams.close
        }
        Promise.resolve()
      },
      cancel: _reason => {
        cancelled.contents = true
        Promise.resolve()
      },
    })
    (body, cancelled, pulls)
  }

  let readText = async body => {
    let reader = body->WebAPI.ReadableStream.getReader
    let chunk = await reader->WebStreams.readChunk
    reader->WebStreams.releaseReader
    let bytes = chunk.value->Nullable.toOption->Option.getOrThrow
    WebStreams.makeTextDecoder()->WebStreams.decode(bytes)
  }

  let controlledStreamWithCancellation = cancel => {
    let controller = ref(None)
    let cancelled = ref(false)
    let body = WebStreams.makeReadableStream({
      start: value => controller.contents = Some(value),
      cancel: _reason => {
        cancelled.contents = true
        cancel()
      },
    })
    (body, controller.contents->Option.getOrThrow, cancelled)
  }

  let controlledStream = () => controlledStreamWithCancellation(() => Promise.resolve())

  let openStream = chunks => {
    let cancelled = ref(false)
    let body = WebStreams.makeReadableStream({
      start: controller => chunks->Array.forEach(chunk => controller->WebStreams.enqueue(chunk)),
      cancel: _reason => {
        cancelled.contents = true
        Promise.resolve()
      },
    })
    (body, cancelled)
  }
}

afterEach(() => Vi.useRealTimers()->ignore)

describe("MCP HTTP body reader", _t => {
  testAsync("reads and concatenates streamed bytes", async t => {
    let (body, _, _) = Helpers.stream(~chunks=[Helpers.encode("hello "), Helpers.encode("world")])

    let result = await BodyReader.read(~headers=Helpers.headers(None), ~body)
    t
    ->expect(WebStreams.makeTextDecoder()->WebStreams.decode(result->Result.getOrThrow))
    ->Expect.toBe("hello world")
    t->expect(body.locked)->Expect.toBe(false)
  })

  testAsync("accepts exactly 2 MiB with matching or missing Content-Length", async t => {
    let bytes = Helpers.encode("a"->String.repeat(BodyDecoder.maxBodyBytes))

    let verify = async contentLength => {
      let (body, _, _) = Helpers.stream(~chunks=[bytes])
      let result = await BodyReader.read(~headers=Helpers.headers(contentLength), ~body)
      t
      ->expect(result->Result.getOrThrow->BodyReader.byteLength)
      ->Expect.toBe(BodyDecoder.maxBodyBytes)
      t->expect(body.locked)->Expect.toBe(false)
    }

    await verify(None)
    await verify(Some(Int.toString(BodyDecoder.maxBodyBytes)))
  })

  testAsync("rejects oversized Content-Length before reading", async t => {
    let (body, _, _) = Helpers.stream(~chunks=[Helpers.encode("{}")])
    let headers = Helpers.headers(Some(Int.toString(BodyDecoder.maxBodyBytes + 1)))

    let result = await BodyReader.read(~headers, ~body)

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTooLarge))
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(await Helpers.readText(body))->Expect.toBe("{}")
  })

  testAsync("independently rejects and cancels an oversized stream", async t => {
    let chunks = [Helpers.encode("a"->String.repeat(BodyDecoder.maxBodyBytes + 1))]

    let verify = async contentLength => {
      let (body, cancelled) = Helpers.openStream(chunks)
      let result = await BodyReader.read(~headers=Helpers.headers(contentLength), ~body)
      t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTooLarge))
      t->expect(cancelled.contents)->Expect.toBe(true)
      t->expect(body.locked)->Expect.toBe(false)
    }

    await verify(None)
    await verify(Some("1"))
  })

  testAsync("accepts the chunk limit and cancels one chunk over it", async t => {
    let emptyChunk = Helpers.encode("")
    let atLimitChunks = Array.make(~length=BodyReader.maxChunks, emptyChunk)
    let (atLimitBody, _, _) = Helpers.stream(~chunks=atLimitChunks)
    let atLimitResult = await BodyReader.read(~headers=Helpers.headers(None), ~body=atLimitBody)
    t->expect(atLimitResult->Result.getOrThrow->BodyReader.byteLength)->Expect.toBe(0)
    t->expect(atLimitBody.locked)->Expect.toBe(false)

    let overLimitChunks = Array.make(~length=BodyReader.maxChunks + 1, emptyChunk)
    let (overLimitBody, cancelled) = Helpers.openStream(overLimitChunks)

    let result = await BodyReader.read(~headers=Helpers.headers(None), ~body=overLimitBody)

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTooFragmented))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(overLimitBody.locked)->Expect.toBe(false)
  })

  testAsync("releases the reader when the stream rejects", async t => {
    Vi.useFakeTimers()->ignore
    let body = WebStreams.makeReadableStream({pull: _controller => Promise.reject(StreamFailed)})

    let rejected = try {
      let _ = await BodyReader.read(~headers=Helpers.headers(None), ~body)
      false
    } catch {
    | StreamFailed => true
    | exn => throw(exn)
    }

    t->expect(rejected)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("times out and cancels after 60,001 milliseconds of inactivity", async t => {
    Vi.useFakeTimers()->ignore
    let (body, _controller, cancelled) = Helpers.controlledStream()
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs)
    t->expect(Vi.getTimerCount())->Expect.toBe(1)
    let _ = await Vi.advanceTimersByTimeAsync(1)
    let result = await reading

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTimedOut))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("resets the deadline for bytes received exactly at 60,000 milliseconds", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, _) = Helpers.controlledStream()
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs)
    controller->WebStreams.enqueue(Helpers.encode("a"))
    let _ = await Vi.advanceTimersByTimeAsync(0)
    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs)
    controller->WebStreams.enqueue(Helpers.encode("b"))
    controller->WebStreams.close
    let result = await reading

    t
    ->expect(WebStreams.makeTextDecoder()->WebStreams.decode(result->Result.getOrThrow))
    ->Expect.toBe("ab")
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("allows body completion exactly at 60,000 milliseconds", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, _) = Helpers.controlledStream()
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs)
    controller->WebStreams.close
    let _ = await Vi.advanceTimersByTimeAsync(0)
    let result = await reading

    t->expect(result->Result.getOrThrow->BodyReader.byteLength)->Expect.toBe(0)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("does not reset the deadline for a zero-byte chunk", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, cancelled) = Helpers.controlledStream()
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs - 1)
    controller->WebStreams.enqueue(Helpers.encode(""))
    let _ = await Vi.advanceTimersByTimeAsync(0)
    let _ = await Vi.advanceTimersByTimeAsync(2)
    let result = await reading

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTimedOut))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("rejects bytes that settle after the monotonic deadline", async t => {
    Vi.useFakeTimers()->ignore
    let (body, controller, cancelled) = Helpers.controlledStream()
    let reader = body->WebAPI.ReadableStream.getReader
    let deadline = BodyReader.monotonicNow()
    BodyReader.setTimeout(() => controller->WebStreams.enqueue(Helpers.encode("late")), 1)->ignore
    let reading = BodyReader.readBeforeDeadline(reader, deadline)

    let _ = await Vi.advanceTimersByTimeAsync(1)
    let result = await reading
    reader->WebStreams.releaseReader

    t->expect(result)->Expect.toEqual(BodyReader.TimedOut)
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("cancels before reading when the monotonic deadline already expired", async t => {
    Vi.useFakeTimers()->ignore
    let (body, _controller, cancelled) = Helpers.controlledStream()
    let reader = body->WebAPI.ReadableStream.getReader

    let result = await BodyReader.readBeforeDeadline(reader, BodyReader.monotonicNow() -. 1.0)
    reader->WebStreams.releaseReader

    t->expect(result)->Expect.toEqual(BodyReader.TimedOut)
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("returns the timeout without awaiting underlying cancellation", async t => {
    Vi.useFakeTimers()->ignore
    let cancellation = () => Promise.make((_resolve, _reject) => ())
    let (body, _controller, cancelled) = Helpers.controlledStreamWithCancellation(cancellation)
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs + 1)
    let result = await reading

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTimedOut))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("keeps the timeout outcome when underlying cancellation rejects", async t => {
    Vi.useFakeTimers()->ignore
    let cancellation = () => Promise.reject(StreamFailed)
    let (body, _controller, cancelled) = Helpers.controlledStreamWithCancellation(cancellation)
    let reading = BodyReader.read(~headers=Helpers.headers(None), ~body)

    let _ = await Vi.advanceTimersByTimeAsync(BodyReader.idleTimeoutMs + 1)
    let result = await reading

    t->expect(result)->Expect.toEqual(Error(BodyReader.BodyTimedOut))
    t->expect(cancelled.contents)->Expect.toBe(true)
    t->expect(body.locked)->Expect.toBe(false)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })

  testAsync("rejects malformed Content-Length before reading", async t => {
    let _ = await ["", "-1", "+1", "1.0", "1, 1", "bytes"]
    ->Array.map(
      async value => {
        let (body, _, _) = Helpers.stream(~chunks=[Helpers.encode("{}")])
        let result = await BodyReader.read(~headers=Helpers.headers(Some(value)), ~body)
        t->expect(result)->Expect.toEqual(Error(BodyReader.InvalidContentLength))
        t->expect(body.locked)->Expect.toBe(false)
        t->expect(await Helpers.readText(body))->Expect.toBe("{}")
      },
    )
    ->Promise.all
  })
})
