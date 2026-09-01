open Vitest

module AdapterSecurity = FrontmanCore__MCP__AdapterSecurity
module HttpSecurity = FrontmanCore__MCP__HttpSecurity

let request = () => {
  let headers = WebAPI.HeadersInit.fromKeyValueArray([("Origin", "https://client.example")])
  WebAPI.Request.fromURL("http://localhost/mcp", ~init={headers: headers})
}

describe("MCP adapter security configuration", _t => {
  testAsync("maps every public authorization decision exactly", async t => {
    let assertDecision = async (~decision, ~expectedStatus) => {
      let policy = AdapterSecurity.make({
        allowedOrigins: ["https://client.example"],
        authorize: async _headers => decision,
      })
      switch await HttpSecurity.validate(~request=request(), ~policy) {
      | HttpSecurity.Allowed(_) => t->expect(expectedStatus)->Expect.toBe(200)
      | HttpSecurity.Rejected(response) => t->expect(response.status)->Expect.toBe(expectedStatus)
      }
    }

    await assertDecision(~decision=#authorized, ~expectedStatus=200)
    await assertDecision(~decision=#"missing-authentication", ~expectedStatus=401)
    await assertDecision(~decision=#"insufficient-authorization", ~expectedStatus=403)
  })

  test("rejects malformed configured origins at adapter construction", t => {
    let crashed = try {
      AdapterSecurity.make({
        allowedOrigins: ["https:client.example"],
        authorize: async _headers => #authorized,
      })->ignore
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("Invalid configured MCP origin: https:client.example")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })
})
