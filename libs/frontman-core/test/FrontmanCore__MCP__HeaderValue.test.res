open Vitest

module HeaderValue = FrontmanCore__MCP__HeaderValue

describe("MCP Streamable HTTP header values", _t => {
  test("accepts safe plain ASCII values", t => {
    [
      "us-west1",
      "hello world",
      "hello\tworld",
      "=?BASE64?SGVsbG8=?=",
      "=?base64?SGVsbG8=",
      "",
    ]->Array.forEach(value => t->expect(HeaderValue.decode(value))->Expect.toEqual(Ok(value)))
  })

  test("decodes Base64 sentinel values", t => {
    [
      ("=?base64?SGVsbG8sIOS4lueVjA==?=", "Hello, 世界"),
      ("=?base64?IHBhZGRlZCA=?=", " padded "),
      ("=?base64?bGluZTEKbGluZTI=?=", "line1\nline2"),
      ("=?base64?PT9iYXNlNjQ/bGl0ZXJhbD89?=", "=?base64?literal?="),
    ]->Array.forEach(
      ((value, expected)) => t->expect(HeaderValue.decode(value))->Expect.toEqual(Ok(expected)),
    )
  })

  test("rejects unsafe unencoded values", t => {
    [
      " padded",
      "padded ",
      "\tpadded",
      "padded\t",
      "Hello, 世界",
      "line1\nline2",
      "line1\rline2",
      "line1\u{0000}line2",
    ]->Array.forEach(
      value =>
        t->expect(HeaderValue.decode(value))->Expect.toEqual(Error(HeaderValue.InvalidCharacters)),
    )
  })

  test("rejects malformed sentinel encoding", t => {
    [
      "=?base64?SGV sbG8=?=",
      "=?base64?SGVsbG8===?=",
      "=?base64?AB==?=",
      "=?base64?/w==?=",
    ]->Array.forEach(
      value =>
        t->expect(HeaderValue.decode(value))->Expect.toEqual(Error(HeaderValue.InvalidEncoding)),
    )
  })
})
