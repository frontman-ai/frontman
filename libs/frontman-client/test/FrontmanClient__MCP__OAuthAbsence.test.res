open Vitest

module MCPClient = FrontmanClient__MCP__Client
module TestServer = FrontmanClient__MCP__OAuthAbsenceTestServer

describe("MCP browser client OAuth absence", _t => {
  testAsync("does not follow a hostile resource_metadata challenge", async t => {
    let server = await TestServer.start()
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t
      ->expect(await MCPClient.connect(client))
      ->Expect.toEqual(Error("Application authentication required"))
      t->expect(server.requestCount())->Expect.toBe(1)
      t->expect(server.originalPostCount())->Expect.toBe(1)
      t->expect(server.oauthDiscoveryCount())->Expect.toBe(0)
      t->expect(server.oauthTokenCount())->Expect.toBe(0)
      t->expect(server.oauthRegistrationCount())->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })
})
