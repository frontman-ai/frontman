open Vitest

module HeaderValue = FrontmanClient__MCP__HeaderValue

describe("MCP header encoding", _t => {
  test("keeps safe ASCII and encodes unsafe or ambiguous values", t => {
    t->expect(HeaderValue.encode("read_file"))->Expect.toBe("read_file")
    t->expect(HeaderValue.encode("cafe"))->Expect.toBe("cafe")
    t->expect(HeaderValue.encode("café"))->Expect.toBe("=?base64?Y2Fmw6k=?=")
    t->expect(HeaderValue.encode(" padded "))->Expect.toBe("=?base64?IHBhZGRlZCA=?=")
    t
    ->expect(HeaderValue.encode("=?base64?literal?="))
    ->Expect.toBe("=?base64?PT9iYXNlNjQ/bGl0ZXJhbD89?=")
  })
})
