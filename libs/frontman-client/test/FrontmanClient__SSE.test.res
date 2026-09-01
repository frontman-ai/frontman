open Vitest

module SSE = FrontmanClient__SSE

describe("parseEventBlock", _t => {
  test("parses single data line", t => {
    let block = "event: result\ndata: hello"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#result)
    t->expect(event.data)->Expect.toBe("hello")
  })

  test("concatenates multi-line data with newlines", t => {
    let block = "event: result\ndata: line 1\ndata: line 2\ndata: line 3"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#result)
    t->expect(event.data)->Expect.toBe("line 1\nline 2\nline 3")
  })

  test("handles event without event type", t => {
    let block = "data: just data"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#unknown)
    t->expect(event.data)->Expect.toBe("just data")
  })

  test("returns None for empty data", t => {
    let block = "event: empty"
    let result = SSE.parseEventBlock(block)

    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for empty block", t => {
    let block = ""
    let result = SSE.parseEventBlock(block)

    t->expect(result)->Expect.toBe(None)
  })

  test("handles progress event", t => {
    let block = "event: progress\ndata: 50%"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#progress)
    t->expect(event.data)->Expect.toBe("50%")
  })

  test("handles error event", t => {
    let block = "event: error\ndata: Something went wrong"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#error)
    t->expect(event.data)->Expect.toBe("Something went wrong")
  })

  test("handles JSON data in data field", t => {
    let block = `event: result\ndata: {"status": "ok", "value": 42}`
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#result)
    t->expect(event.data)->Expect.toBe(`{"status": "ok", "value": 42}`)
  })

  test("trims whitespace from event type and data", t => {
    let block = "event:   result   \ndata:   hello world   "
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#result)
    t->expect(event.data)->Expect.toBe("hello world")
  })

  test("ignores comment lines", t => {
    let block = ": this is a comment\nevent: result\ndata: value"
    let result = SSE.parseEventBlock(block)

    t->expect(result->Option.isSome)->Expect.toBe(true)
    let event = result->Option.getOrThrow
    t->expect(event.eventType)->Expect.toBe(#result)
    t->expect(event.data)->Expect.toBe("value")
  })
})
