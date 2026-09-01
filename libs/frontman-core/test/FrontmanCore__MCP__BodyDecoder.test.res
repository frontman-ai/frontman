open Vitest

module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module WebStreams = FrontmanBindings.WebStreams

module Helpers = {
  @new
  external bytes: array<int> => Uint8Array.t = "Uint8Array"

  let encode = value => WebStreams.makeTextEncoder()->WebStreams.encode(value)

  let nestedArray = depth => "["->String.repeat(depth) ++ "0" ++ "]"->String.repeat(depth)

  let nestedObject = depth => `{"value":`->String.repeat(depth) ++ "0" ++ "}"->String.repeat(depth)
}

describe("MCP JSON body decoder", _t => {
  test("decodes one UTF-8 JSON value without narrowing its root", t => {
    [
      `{"message":"Hello, 世界"}`,
      `[1,true,null,"value"]`,
      `"value"`,
      `42.5`,
      `true`,
      `null`,
    ]->Array.forEach(
      source =>
        t
        ->expect(BodyDecoder.decode(Helpers.encode(source))->Result.getOrThrow->JSON.stringify)
        ->Expect.toBe(source),
    )
  })

  test("accepts the exact body byte limit and rejects one byte over it", t => {
    let atLimit = `"${"a"->String.repeat(BodyDecoder.maxBodyBytes - 2)}"`
    let overLimit = `"${"a"->String.repeat(BodyDecoder.maxBodyBytes - 1)}"`

    t->expect(BodyDecoder.decode(Helpers.encode(atLimit))->Result.isOk)->Expect.toBe(true)
    t
    ->expect(BodyDecoder.decode(Helpers.encode(overLimit)))
    ->Expect.toEqual(Error(BodyDecoder.BodyTooLarge))
  })

  test("rejects malformed and truncated UTF-8 before JSON parsing", t => {
    [Helpers.bytes([0xFF]), Helpers.bytes([0x22, 0xE2, 0x82])]->Array.forEach(
      bytes => t->expect(BodyDecoder.decode(bytes))->Expect.toEqual(Error(BodyDecoder.InvalidUtf8)),
    )
  })

  test("accepts JSON depth 64 and rejects depth 65", t => {
    [Helpers.nestedArray, Helpers.nestedObject]->Array.forEach(
      nested => {
        t
        ->expect(BodyDecoder.decode(Helpers.encode(nested(BodyDecoder.maxJsonDepth)))->Result.isOk)
        ->Expect.toBe(true)
        t
        ->expect(BodyDecoder.decode(Helpers.encode(nested(BodyDecoder.maxJsonDepth + 1))))
        ->Expect.toEqual(Error(BodyDecoder.JsonTooDeep))
      },
    )
  })

  test("ignores structural characters and escapes inside strings when measuring depth", t => {
    let brackets = "["->String.repeat(BodyDecoder.maxJsonDepth + 1)

    [brackets, "\"" ++ brackets, "\\" ++ brackets, "\\\"" ++ brackets]->Array.forEach(
      value => {
        let source = `{"value":${value->S.decodeOrThrow(~from=S.string, ~to=S.jsonString)}}`
        t->expect(BodyDecoder.decode(Helpers.encode(source))->Result.isOk)->Expect.toBe(true)
      },
    )
  })

  test("rejects malformed JSON and multiple JSON values", t => {
    [``, `{`, `{"value":}`, `{} {}`]->Array.forEach(
      source =>
        t
        ->expect(BodyDecoder.decode(Helpers.encode(source)))
        ->Expect.toEqual(Error(BodyDecoder.InvalidJson)),
    )
  })
})
