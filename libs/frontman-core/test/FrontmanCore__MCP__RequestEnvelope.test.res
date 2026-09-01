open Vitest

module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope

module Helpers = {
  let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)
}

describe("MCP Streamable HTTP request envelope", _t => {
  test("accepts requests and preserves open fields and arbitrary params", t => {
    [
      `{"jsonrpc":"2.0","id":"","method":""}`,
      `{"jsonrpc":"2.0","id":-9007199254740991,"method":"vendor/min","params":null}`,
      `{"jsonrpc":"2.0","id":9007199254740991,"method":"vendor/max","params":[]}`,
      `{"jsonrpc":"2.0","id":"request-1","method":"vendor/scalar","params":true}`,
      `{"jsonrpc":"2.0","id":"request-2","method":"vendor/number","params":1.5}`,
      `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"read_file"},"vendor":{"preserved":[null,1.5]}}`,
    ]->Array.forEach(
      source => {
        let envelope = RequestEnvelope.classify(Helpers.json(source))->Result.getOrThrow
        t->expect(envelope.raw)->Expect.toEqual(Helpers.json(source))
      },
    )
  })

  test("returns typed ID and method without narrowing params", t => {
    let envelope =
      RequestEnvelope.classify(
        Helpers.json(`{"jsonrpc":"2.0","id":9007199254740991,"method":"tools/call","params":"deferred"}`),
      )->Result.getOrThrow

    t->expect(envelope.id->JsonRpc.Id.toJson)->Expect.toEqual(Helpers.json("9007199254740991"))
    t->expect(envelope.method)->Expect.toBe("tools/call")
    t->expect(envelope.params->Option.getOrThrow)->Expect.toEqual(Helpers.json(`"deferred"`))
  })

  test("rejects malformed envelopes and unsupported incoming directions", t => {
    [
      `null`,
      `[]`,
      `"request"`,
      `1`,
      `{}`,
      `{"jsonrpc":"1.0","id":"request-1","method":"tools/call"}`,
      `{"jsonrpc":"2.0","method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":null,"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":1.5,"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":-9007199254740992,"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":9007199254740992,"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":true,"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":{},"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":[],"method":"tools/call"}`,
      `{"jsonrpc":"2.0","id":"request-1"}`,
      `{"jsonrpc":"2.0","id":"request-1","method":1}`,
      `{"jsonrpc":"2.0","method":"notifications/progress","params":{}}`,
      `{"jsonrpc":"2.0","id":"request-1","result":{"resultType":"complete"}}`,
      `{"jsonrpc":"2.0","id":"request-1","error":{"code":-32603,"message":"failed"}}`,
      `{"jsonrpc":"2.0","id":"request-1","method":"tools/call","result":{"resultType":"complete"}}`,
      `{"jsonrpc":"2.0","id":"request-1","method":"tools/call","error":{"code":-32603,"message":"failed"}}`,
    ]->Array.forEach(
      source =>
        t
        ->expect(RequestEnvelope.classify(Helpers.json(source)))
        ->Expect.toEqual(Error(RequestEnvelope.InvalidEnvelopeOrDirection)),
    )
  })

  test("recovers readable IDs without accepting the surrounding invalid envelope", t => {
    [
      (`{"jsonrpc":"1.0","id":"wrong-version","method":"tools/call"}`, `"wrong-version"`),
      (`{"jsonrpc":"2.0","id":"missing-method"}`, `"missing-method"`),
      (`{"jsonrpc":"2.0","id":"wrong-method","method":1}`, `"wrong-method"`),
      (`{"jsonrpc":"2.0","id":-9007199254740991,"result":{}}`, `-9007199254740991`),
      (`{"jsonrpc":"2.0","id":9007199254740991,"error":{}}`, `9007199254740991`),
      (`{"jsonrpc":"2.0","id":1,"method":"tools/call","result":{}}`, `1`),
    ]->Array.forEach(
      ((source, expectedId)) => {
        let json = Helpers.json(source)

        t
        ->expect(RequestEnvelope.classify(json))
        ->Expect.toEqual(Error(RequestEnvelope.InvalidEnvelopeOrDirection))
        t
        ->expect(RequestEnvelope.recoverId(json)->Option.map(JsonRpc.Id.toJson))
        ->Expect.toEqual(Some(Helpers.json(expectedId)))
      },
    )
  })

  test("does not recover missing or unreadable IDs", t => {
    [
      `null`,
      `[]`,
      `{}`,
      `{"id":null}`,
      `{"id":1.5}`,
      `{"id":-9007199254740992}`,
      `{"id":9007199254740992}`,
      `{"id":true}`,
      `{"id":{}}`,
      `{"id":[]}`,
    ]->Array.forEach(
      source => t->expect(RequestEnvelope.recoverId(Helpers.json(source)))->Expect.toBeNone,
    )
  })
})
