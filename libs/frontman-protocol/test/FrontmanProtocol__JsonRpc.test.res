open Vitest

module JsonRpc = FrontmanProtocol__JsonRpc

let parses = (schema, json) => {
  try {
    json->JSON.parseOrThrow->S.parseOrThrow(~to=schema)->ignore
    true
  } catch {
  | _ => false
  }
}

describe("JSON-RPC wire contracts", () => {
  test("requires version 2.0 and string or integer request IDs", t => {
    let valid = [
      `{"jsonrpc":"2.0","id":"request-1","method":"tools/list"}`,
      `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`,
    ]
    let invalid = [
      `{"jsonrpc":"1.0","id":1,"method":"tools/list"}`,
      `{"jsonrpc":"2.0","id":1.5,"method":"tools/list"}`,
    ]

    valid->Array.forEach(json => t->expect(parses(JsonRpc.Request.schema, json))->Expect.toBe(true))
    invalid->Array.forEach(
      json => t->expect(parses(JsonRpc.Request.schema, json))->Expect.toBe(false),
    )
  })

  test("requires success ID and result without error", t => {
    let valid = `{"jsonrpc":"2.0","id":"request-1","result":null}`
    let invalid = [
      `{"jsonrpc":"2.0","result":null}`,
      `{"jsonrpc":"2.0","id":1}`,
      `{"jsonrpc":"2.0","id":1,"result":{},"error":{"code":-32603,"message":"failed"}}`,
    ]

    t->expect(parses(JsonRpc.Response.schema, valid))->Expect.toBe(true)
    invalid->Array.forEach(
      json => t->expect(parses(JsonRpc.Response.schema, json))->Expect.toBe(false),
    )
  })

  test("permits omitted error ID and forbids result", t => {
    let valid = [
      `{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"failed"}}`,
      `{"jsonrpc":"2.0","error":{"code":-32600,"message":"unreadable request"}}`,
    ]
    let invalid = `{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"failed"},"result":null}`

    valid->Array.forEach(
      json => t->expect(parses(JsonRpc.Response.schema, json))->Expect.toBe(true),
    )
    t->expect(parses(JsonRpc.Response.schema, invalid))->Expect.toBe(false)
  })
})
