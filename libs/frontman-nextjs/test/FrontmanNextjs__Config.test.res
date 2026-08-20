open Vitest

module Config = FrontmanNextjs__Config
module HttpSecurity = FrontmanAiFrontmanCore.FrontmanCore__MCP__HttpSecurity

describe("Next.js MCP adapter configuration", _t => {
  testAsync("constructs explicit security policy without deriving an origin", async t => {
    let config = Config.makeFromObject({
      clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
      mcp: {
        allowedOrigins: ["https://CLIENT.example:443"],
        authorize: async _headers => #authorized,
      },
    })
    let policy = config.mcpSecurity->Option.getOrThrow
    let sourceLocationPolicy = config.sourceLocationSecurity->Option.getOrThrow
    let headers = WebAPI.HeadersInit.fromKeyValueArray([("Origin", "https://client.example")])
    let request = WebAPI.Request.fromURL("http://attacker.invalid/mcp", ~init={headers: headers})

    switch await HttpSecurity.validate(~request, ~policy) {
    | HttpSecurity.Allowed(origin) => t->expect(origin)->Expect.toBe("https://client.example")
    | HttpSecurity.Rejected(_) => failwith("Expected configured Origin acceptance")
    }
    switch HttpSecurity.validateOriginHeaders(
      ~headers=request.headers,
      ~policy=sourceLocationPolicy,
    ) {
    | HttpSecurity.ValidOrigin(origin) => t->expect(origin)->Expect.toBe("https://client.example")
    | HttpSecurity.InvalidOrigin(_) => failwith("Expected MCP Origin inheritance")
    }
  })

  test("prefers an explicit source-location allowlist", t => {
    let config = Config.makeFromObject({
      clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
      mcp: {
        allowedOrigins: ["https://mcp.example"],
        authorize: async _headers => #authorized,
      },
      sourceLocation: {allowedOrigins: ["https://source.example"]},
    })
    let policy = config.sourceLocationSecurity->Option.getOrThrow
    let headers = WebAPI.Headers.fromKeyValueArray([("Origin", "https://source.example")])

    switch HttpSecurity.validateOriginHeaders(~headers, ~policy) {
    | HttpSecurity.ValidOrigin(origin) => t->expect(origin)->Expect.toBe("https://source.example")
    | HttpSecurity.InvalidOrigin(_) => failwith("Expected explicit source-location Origin")
    }
  })

  test("rejects malformed explicit origins during configuration", t => {
    let crashed = try {
      Config.makeFromObject({
        clientUrl: "http://localhost:3000/client.js?clientName=nextjs&host=localhost:3000",
        mcp: {
          allowedOrigins: ["https:client.example"],
          authorize: async _headers => #authorized,
        },
      })->ignore
      false
    } catch {
    | Failure(_) => true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })
})
