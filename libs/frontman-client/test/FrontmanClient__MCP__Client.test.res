open Vitest

module MCPClient = FrontmanClient__MCP__Client
module TestServer = FrontmanClient__MCP__TestServer

afterEach(() => Vi.useRealTimers()->ignore)

let expectConnected = (t, client) =>
  switch MCPClient.getState(client) {
  | Connected(_) => t->expect(true)->Expect.toBe(true)
  | Disconnected | Error(_) => t->expect(false)->Expect.toBe(true)
  }

let expectError = (t, client, expected) =>
  switch MCPClient.getState(client) {
  | Error(message) => t->expect(message)->Expect.toBe(expected)
  | Disconnected | Connected(_) => t->expect(false)->Expect.toBe(true)
  }

let testAcceptedScenario = async (t, scenario, ~toolCount, ~listCount) => {
  let server = await TestServer.startScenario(scenario)
  let client = MCPClient.make(~baseUrl=server.baseUrl)
  try {
    t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
    expectConnected(t, client)
    t->expect(client->MCPClient.getToolsJson->Array.length)->Expect.toBe(toolCount)
    MCPClient.disconnect(client)
    t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
    expectConnected(t, client)
    t->expect(server.counts().discoveryCount)->Expect.toBe(1)
    t->expect(server.counts().listCount)->Expect.toBe(listCount)
  } catch {
  | exn =>
    await server.close()
    throw(exn)
  }
  await server.close()
}

let testRejectedScenario = async (t, scenario, expected, ~listCount) => {
  let server = await TestServer.startScenario(scenario)
  let client = MCPClient.make(~baseUrl=server.baseUrl)
  try {
    t->expect(await MCPClient.connect(client))->Expect.toEqual(Error(expected))
    expectError(t, client, expected)
    t->expect(client->MCPClient.getToolsJson->Array.length)->Expect.toBe(0)
    t->expect(await MCPClient.connect(client))->Expect.toEqual(Error(expected))
    expectError(t, client, expected)
    t->expect(client->MCPClient.getToolsJson->Array.length)->Expect.toBe(0)
    t->expect(server.counts().discoveryCount)->Expect.toBe(2)
    t->expect(server.counts().listCount)->Expect.toBe(listCount * 2)
  } catch {
  | exn =>
    await server.close()
    throw(exn)
  }
  await server.close()
}

describe("MCPClient.connect", _t => {
  testAsync("sets state to Error when the MCP server is unreachable", async t => {
    let client = MCPClient.make(~baseUrl="http://localhost:19999")
    let result = await MCPClient.connect(client)

    t->expect(result->Result.isError)->Expect.toBe(true)
    switch MCPClient.getState(client) {
    | Error(_) => t->expect(true)->Expect.toBe(true)
    | Disconnected | Connected(_) => t->expect(false)->Expect.toBe(true)
    }
  })

  testAsync("retries discovery once when the server confirms the same version", async t => {
    let server = await TestServer.startScenario("same-version-retry")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      expectConnected(t, client)
      t->expect(server.counts().discoveryCount)->Expect.toBe(2)
      t->expect(server.counts().listCount)->Expect.toBe(2)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("lets a terminal HTTP response at exactly 600,000 ms win", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("absolute-deadline")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let connecting = MCPClient.connect(client)
    try {
      await server.controlledReceived
      let _ = await Vi.advanceTimersByTimeAsync(600000)
      t->expect(Vi.getTimerCount())->Expect.toBe(1)
      server.respondControlled()

      t->expect(await connecting)->Expect.toEqual(Ok())
      expectConnected(t, client)
      let _ = await Vi.advanceTimersByTimeAsync(1)
      expectConnected(t, client)
      await server.close()
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("settles one timeout at 600,001 ms and ignores a late response", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("absolute-deadline")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let connecting = MCPClient.connect(client)
    try {
      await server.controlledReceived
      let _ = await Vi.advanceTimersByTimeAsync(600001)

      t->expect(await connecting)->Expect.toEqual(Error("MCP request timed out"))
      expectError(t, client, "MCP request timed out")
      await server.controlledClientClosed
      server.respondControlled()
      let _ = await Vi.advanceTimersByTimeAsync(0)
      expectError(t, client, "MCP request timed out")
      t->expect(Vi.getTimerCount())->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("keeps caller cancellation distinct and clears the deadline", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("absolute-deadline")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let controller = WebAPI.AbortController.make()
    let connecting = MCPClient.connect(client, ~signal=controller.signal)
    try {
      await server.controlledReceived
      controller->WebAPI.AbortController.abort

      t->expect(await connecting)->Expect.toEqual(Error("Request cancelled"))
      expectError(t, client, "Request cancelled")
      await server.controlledClientClosed
      t->expect(Vi.getTimerCount())->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("aborts the request-owned fetch after a response error", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("response-error")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      let connecting = MCPClient.connect(client)
      await server.controlledReceived

      t
      ->expect(await connecting)
      ->Expect.toEqual(Error("Unsupported MCP response media type: text/plain"))
      await server.controlledClientClosed
      t->expect(Vi.getTimerCount())->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("does not reconnect after disconnecting a pending connect", async t => {
    let server = await TestServer.startScenario("connect-lifecycle")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let connecting = MCPClient.connect(client)
    try {
      await server.waitForControlled(1)
      MCPClient.disconnect(client)
      server.respondControlledAt(0)

      t->expect(await connecting)->Expect.toEqual(Error("Request cancelled"))
      switch MCPClient.getState(client) {
      | Disconnected => t->expect(true)->Expect.toBe(true)
      | Connected(_) | Error(_) => t->expect(false)->Expect.toBe(true)
      }
      t->expect(server.counts().listCount)->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("keeps the newest concurrent connect state and cache", async t => {
    let server = await TestServer.startScenario("connect-lifecycle")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let older = MCPClient.connect(client)
    try {
      await server.waitForControlled(1)
      let newer = MCPClient.connect(client)
      await server.waitForControlled(2)
      server.respondControlledAt(1)
      t->expect(await newer)->Expect.toEqual(Ok())
      t->expect(client->MCPClient.hasTool("new_tool"))->Expect.toBe(true)

      server.respondControlledAt(0)
      t->expect(await older)->Expect.toEqual(Error("Request cancelled"))
      t->expect(client->MCPClient.hasTool("new_tool"))->Expect.toBe(true)
      t->expect(client->MCPClient.hasTool("old_tool"))->Expect.toBe(false)

      MCPClient.disconnect(client)
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t->expect(client->MCPClient.hasTool("new_tool"))->Expect.toBe(true)
      t->expect(server.counts().discoveryCount)->Expect.toBe(2)
      t->expect(server.counts().listCount)->Expect.toBe(1)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })
})

describe("MCP client Streamable HTTP", _t => {
  testAsync("treats absent discovery resultType as complete", async t => {
    await testAcceptedScenario(t, "absent-discovery-result-type", ~toolCount=6, ~listCount=2)
  })

  testAsync("treats absent list resultType as complete", async t => {
    await testAcceptedScenario(t, "absent-list-result-type", ~toolCount=1, ~listCount=1)
  })

  testAsync("treats absent tools/call resultType as complete", async t => {
    let server = await TestServer.startScenario("absent-call-result-type")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t
      ->expect((await MCPClient.executeTool(client, ~name="result_type_tool"))->Result.isOk)
      ->Expect.toBe(true)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("keeps discovery and list results complete-only", async t => {
    await testRejectedScenario(
      t,
      "input-required-discovery",
      "Unsupported MCP result type: input_required",
      ~listCount=0,
    )
    await testRejectedScenario(
      t,
      "input-required-list",
      "Unsupported MCP result type: input_required",
      ~listCount=1,
    )
  })

  testAsync("validates and surfaces input_required without retrying", async t => {
    let server = await TestServer.startScenario("input-required-call")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t
      ->expect(await MCPClient.executeTool(client, ~name="result_type_tool"))
      ->Expect.toEqual(Error("MCP tool requires additional input"))
      t->expect(server.counts().callCount)->Expect.toBe(1)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("rejects malformed input_required results", async t => {
    let server = await TestServer.startScenario("malformed-input-required-call")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t
      ->expect(await MCPClient.executeTool(client, ~name="result_type_tool"))
      ->Expect.toEqual(Error("Invalid MCP input_required result"))
      t->expect(server.counts().callCount)->Expect.toBe(1)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync(
    "discovers, paginates, filters invalid tools, caches, and calls over JSON and SSE",
    async t => {
      let server = await TestServer.start()
      let client = MCPClient.make(
        ~baseUrl=server.baseUrl,
        ~requestHeaders=Dict.fromArray([("Authorization", "Bearer test")]),
      )

      try {
        t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
        t->expect(client->MCPClient.hasTool("write_unicode"))->Expect.toBe(true)
        t->expect(client->MCPClient.hasTool("json_tool"))->Expect.toBe(true)
        t->expect(client->MCPClient.hasTool("invalid_remote"))->Expect.toBe(false)
        t->expect(client->MCPClient.getToolsJson->Array.length)->Expect.toBe(6)

        MCPClient.disconnect(client)
        t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
        t->expect(server.counts().discoveryCount)->Expect.toBe(1)
        t->expect(server.counts().listCount)->Expect.toBe(2)

        let arguments = Dict.fromArray([("value", JSON.Encode.string("café"))])
        t
        ->expect(
          (await MCPClient.executeTool(client, ~name="write_unicode", ~arguments))->Result.isOk,
        )
        ->Expect.toBe(true)
        t
        ->expect((await MCPClient.executeTool(client, ~name="json_tool"))->Result.isOk)
        ->Expect.toBe(true)
        t
        ->expect((await MCPClient.executeTool(client, ~name="retry_header"))->Result.isOk)
        ->Expect.toBe(true)
        t->expect(server.counts().headerMismatchCount)->Expect.toBe(2)
        t->expect(server.counts().discoveryCount)->Expect.toBe(2)
        t->expect(server.counts().listCount)->Expect.toBe(4)

        let discovery = server.requests[0]->Option.getOrThrow
        t
        ->expect(discovery.headers->Dict.get("accept"))
        ->Expect.toEqual(Some("application/json, text/event-stream"))
        t
        ->expect(discovery.headers->Dict.get("mcp-protocol-version"))
        ->Expect.toEqual(Some("2026-07-28"))
        t->expect(discovery.headers->Dict.get("authorization"))->Expect.toEqual(Some("Bearer test"))

        let sseCall = server.requests[3]->Option.getOrThrow
        t->expect(sseCall.headers->Dict.get("mcp-method"))->Expect.toEqual(Some("tools/call"))
        t->expect(sseCall.headers->Dict.get("mcp-name"))->Expect.toEqual(Some("write_unicode"))
        t
        ->expect(sseCall.headers->Dict.get("mcp-param-value"))
        ->Expect.toEqual(Some("=?base64?Y2Fmw6k=?="))
      } catch {
      | exn =>
        await server.close()
        throw(exn)
      }
      await server.close()
    },
  )

  testAsync("rejects invalid arguments before issuing a request", async t => {
    let server = await TestServer.start()
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      let before = server.requests->Array.length
      t
      ->expect(await MCPClient.executeTool(client, ~name="write_unicode"))
      ->Expect.toEqual(Error("Invalid tool arguments"))
      t->expect(server.requests->Array.length)->Expect.toBe(before)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("bounds input and output validation without sending or retrying execution", async t => {
    let server = await TestServer.start()
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())

      let beforeInput = server.requests->Array.length
      let arguments = Dict.fromArray([("value", JSON.Encode.string("a"->String.repeat(64) ++ "!"))])
      t
      ->expect(await MCPClient.executeTool(client, ~name="slow_input", ~arguments))
      ->Expect.toEqual(Error("Tool argument validation timed out"))
      t->expect(server.requests->Array.length)->Expect.toBe(beforeInput)

      let discoveryCount = server.counts().discoveryCount
      let listCount = server.counts().listCount
      let beforeOutput = server.requests->Array.length
      t
      ->expect(await MCPClient.executeTool(client, ~name="slow_output"))
      ->Expect.toEqual(Error("Tool output validation timed out"))
      t->expect(server.requests->Array.length)->Expect.toBe(beforeOutput + 1)
      t->expect(server.counts().discoveryCount)->Expect.toBe(discoveryCount)
      t->expect(server.counts().listCount)->Expect.toBe(listCount)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("accepts a 12,582,912-byte JSON response", async t => {
    await testAcceptedScenario(t, "json-response-12582912", ~toolCount=6, ~listCount=2)
  })

  testAsync("rejects a 12,582,913-byte JSON response without caching", async t => {
    await testRejectedScenario(
      t,
      "json-response-12582913",
      "MCP response exceeds the byte limit",
      ~listCount=0,
    )
  })

  testAsync("accepts a 12,582,912-byte byte-split SSE response", async t => {
    await testAcceptedScenario(t, "sse-response-12582912", ~toolCount=6, ~listCount=2)
  })

  testAsync("rejects a 12,582,913-byte byte-split SSE response without caching", async t => {
    await testRejectedScenario(
      t,
      "sse-response-12582913",
      "MCP response exceeds the byte limit",
      ~listCount=0,
    )
  })

  testAsync("accepts exactly 32 tool pages", async t => {
    await testAcceptedScenario(t, "pages-32", ~toolCount=32, ~listCount=32)
  })

  testAsync("rejects a 33rd tool page without caching", async t => {
    await testRejectedScenario(
      t,
      "pages-33",
      "MCP tools/list exceeded the page limit",
      ~listCount=32,
    )
  })

  testAsync("accepts exactly 256 tools", ~timeout=15000, async t => {
    await testAcceptedScenario(t, "tools-256", ~toolCount=256, ~listCount=1)
  })

  testAsync("rejects 257 tools without caching", async t => {
    await testRejectedScenario(
      t,
      "tools-257",
      "MCP tools/list exceeded the tool limit",
      ~listCount=1,
    )
  })

  testAsync("accepts a cursor of exactly 4,096 UTF-8 bytes", async t => {
    await testAcceptedScenario(t, "cursor-4096", ~toolCount=2, ~listCount=2)
  })

  testAsync("rejects a cursor of 4,097 UTF-8 bytes without caching", async t => {
    await testRejectedScenario(
      t,
      "cursor-4097",
      "MCP tools/list cursor exceeds the byte limit",
      ~listCount=1,
    )
  })

  testAsync("does not infer meaning from repeated opaque cursors", async t => {
    await testAcceptedScenario(t, "repeated-opaque-cursor", ~toolCount=3, ~listCount=3)
  })

  testAsync("restarts once from page one after a cursor-bearing invalid params error", async t => {
    let server = await TestServer.startScenario("invalid-cursor-restart")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t->expect(client->MCPClient.hasTool("discarded_tool"))->Expect.toBe(false)
      t->expect(client->MCPClient.hasTool("fresh_first"))->Expect.toBe(true)
      t->expect(client->MCPClient.hasTool("fresh_second"))->Expect.toBe(true)
      t->expect(server.counts().listCount)->Expect.toBe(4)
      t->expect(server.counts().discoveryCount)->Expect.toBe(1)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("bounds invalid-cursor restart to one attempt", async t => {
    let server = await TestServer.startScenario("invalid-cursor-restart-bounded")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    try {
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Error("Invalid cursor"))
      t->expect(server.counts().listCount)->Expect.toBe(4)
      t->expect(client->MCPClient.getToolsJson->Array.length)->Expect.toBe(0)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("starts cache TTL after a delayed discovery response", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("cache-delayed-discovery")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let connecting = MCPClient.connect(client)
    try {
      await server.controlledReceived
      let _ = await Vi.advanceTimersByTimeAsync(30000)
      server.respondControlled()
      t->expect(await connecting)->Expect.toEqual(Ok())

      MCPClient.disconnect(client)
      let _ = await Vi.advanceTimersByTimeAsync(59999)
      let cached = MCPClient.connect(client)
      let _ = await Vi.advanceTimersByTimeAsync(0)
      t->expect(server.counts().discoveryCount)->Expect.toBe(1)
      t->expect(await cached)->Expect.toEqual(Ok())

      MCPClient.disconnect(client)
      let _ = await Vi.advanceTimersByTimeAsync(1)
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t->expect(server.counts().discoveryCount)->Expect.toBe(2)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("does not extend an earlier page TTL while waiting for a later page", async t => {
    Vi.useFakeTimers()->ignore
    let server = await TestServer.startScenario("cache-delayed-page")
    let client = MCPClient.make(~baseUrl=server.baseUrl)
    let connecting = MCPClient.connect(client)
    try {
      await server.controlledReceived
      let _ = await Vi.advanceTimersByTimeAsync(30000)
      server.respondControlledAt(0)
      t->expect(await connecting)->Expect.toEqual(Ok())

      MCPClient.disconnect(client)
      let _ = await Vi.advanceTimersByTimeAsync(29999)
      t->expect(await MCPClient.connect(client))->Expect.toEqual(Ok())
      t->expect(server.counts().discoveryCount)->Expect.toBe(1)

      MCPClient.disconnect(client)
      let _ = await Vi.advanceTimersByTimeAsync(1)
      let refreshing = MCPClient.connect(client)
      await server.waitForControlled(2)
      t->expect(server.counts().discoveryCount)->Expect.toBe(2)
      server.respondControlledAt(1)
      t->expect(await refreshing)->Expect.toEqual(Ok())
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })

  testAsync("accepts a 65,536-byte compact tool definition with a valid sibling", async t => {
    await testAcceptedScenario(t, "tool-bytes-65536", ~toolCount=2, ~listCount=1)
  })

  testAsync(
    "filters a 65,537-byte compact tool definition and caches its valid sibling",
    async t => {
      await testAcceptedScenario(t, "tool-bytes-65537", ~toolCount=1, ~listCount=1)
    },
  )

  testAsync("accepts a 1,048,576-byte catalog across pages", async t => {
    await testAcceptedScenario(t, "catalog-bytes-1048576", ~toolCount=17, ~listCount=2)
  })

  testAsync("rejects a 1,048,577-byte catalog across pages without caching", async t => {
    await testRejectedScenario(
      t,
      "catalog-bytes-1048577",
      "MCP tool catalog exceeds the byte limit",
      ~listCount=2,
    )
  })

  testAsync("isolates authorization contexts and snapshots request headers at make", async t => {
    let server = await TestServer.startScenario("authorization-isolation")
    let firstHeaders = Dict.fromArray([("Authorization", "Bearer alpha")])
    let secondHeaders = Dict.fromArray([("Authorization", "Bearer beta")])
    let first = MCPClient.make(~baseUrl=server.baseUrl, ~requestHeaders=firstHeaders)
    let second = MCPClient.make(~baseUrl=server.baseUrl, ~requestHeaders=secondHeaders)
    firstHeaders->Dict.set("Authorization", "Bearer mutated")
    secondHeaders->Dict.set("Authorization", "Bearer mutated")
    try {
      t->expect(await MCPClient.connect(first))->Expect.toEqual(Ok())
      t->expect(await MCPClient.connect(second))->Expect.toEqual(Ok())
      t->expect(first->MCPClient.hasTool("alpha_tool"))->Expect.toBe(true)
      t->expect(first->MCPClient.hasTool("beta_tool"))->Expect.toBe(false)
      t->expect(second->MCPClient.hasTool("beta_tool"))->Expect.toBe(true)
      t->expect(second->MCPClient.hasTool("alpha_tool"))->Expect.toBe(false)
      MCPClient.disconnect(first)
      MCPClient.disconnect(second)
      t->expect(await MCPClient.connect(first))->Expect.toEqual(Ok())
      t->expect(await MCPClient.connect(second))->Expect.toEqual(Ok())
      t->expect(server.counts().discoveryCount)->Expect.toBe(2)
      t->expect(server.counts().listCount)->Expect.toBe(2)
      t->expect(server.counts().authorizationAlphaCount)->Expect.toBe(2)
      t->expect(server.counts().authorizationBetaCount)->Expect.toBe(2)
      t->expect(server.counts().authorizationMutatedCount)->Expect.toBe(0)
      t->expect(server.requests->Array.length)->Expect.toBe(4)
    } catch {
    | exn =>
      await server.close()
      throw(exn)
    }
    await server.close()
  })
})
