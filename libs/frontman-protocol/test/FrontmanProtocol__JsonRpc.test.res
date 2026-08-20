open Vitest

module Id = FrontmanProtocol__JsonRpc.Id

describe("JSON-RPC identifiers", _t => {
  test("constructs numeric and string identifiers", t => {
    t->expect(Id.fromInt(42)->Id.toJson)->Expect.toEqual(JSON.Encode.int(42))
    t
    ->expect(Id.fromString("request-42")->Id.toJson)
    ->Expect.toEqual(JSON.Encode.string("request-42"))
  })

  test("accepts the JavaScript safe integer boundaries", t => {
    let minimum = JSON.Encode.float(-9007199254740991.)
    let maximum = JSON.Encode.float(9007199254740991.)

    t->expect(minimum->S.parseOrThrow(~to=Id.schema)->Id.toJson)->Expect.toEqual(minimum)
    t->expect(maximum->S.parseOrThrow(~to=Id.schema)->Id.toJson)->Expect.toEqual(maximum)
  })

  test("rejects unsafe and fractional numeric identifiers", t => {
    t
    ->expect(() => JSON.Encode.float(9007199254740992.)->S.parseOrThrow(~to=Id.schema)->ignore)
    ->Expect.toThrow
    t->expect(() => JSON.Encode.float(1.5)->S.parseOrThrow(~to=Id.schema)->ignore)->Expect.toThrow
  })
})
