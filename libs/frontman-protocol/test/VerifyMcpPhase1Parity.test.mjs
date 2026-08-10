import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  CallToolRequest,
  CallToolResult,
  CancelledNotification,
  DiscoverRequest,
  DiscoverResult,
  ListToolsRequest,
  ListToolsResult,
  UnsupportedProtocolVersionError,
  protocolVersion,
} from "../src/FrontmanProtocol__MCP.res.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const fixtures = await readJson(new URL("fixtures/mcp-phase1-parity.json", import.meta.url))
const contracts = [
  ["discoverRequest", DiscoverRequest.schema, "discoverRequest"],
  ["discoverResult", DiscoverResult.schema, "discoverResult"],
  ["listRequest", ListToolsRequest.schema, "listToolsRequest"],
  ["listResult", ListToolsResult.schema, "listToolsResult"],
  ["callRequest", CallToolRequest.schema, "callToolRequest"],
  ["completeResult", CallToolResult.schema, "callToolResult"],
  ["namedError", UnsupportedProtocolVersionError.schema, "unsupportedProtocolVersionError"],
  ["cancellation", CancelledNotification.schema, "cancelledNotification"],
]
const ajv = new Ajv2020({strict: true})
addFormats(ajv)

test("Phase 1 fixtures round-trip through runtime and generated schemas", async () => {
  for (const [fixtureName, runtimeSchema, generatedName] of contracts) {
    const fixture = fixtures[fixtureName]
    const parsed = S.parseOrThrow(fixture, runtimeSchema)
    const encoded = JSON.parse(JSON.stringify(S.decodeOrThrow(parsed, runtimeSchema, S.json)))
    const generatedSchema = await readJson(
      new URL(`../schemas/mcp/${generatedName}.json`, import.meta.url),
    )

    assert.deepEqual(encoded, fixture)
    assert.equal(ajv.compile(generatedSchema)(fixture), true)
  }
})

test("Phase 1 fixtures preserve string and numeric request IDs", () => {
  assert.equal(protocolVersion, "2026-07-28")
  assert.equal(fixtures.discoverRequest.id, "discover-1")
  assert.equal(fixtures.listRequest.id, 2)
  assert.equal(fixtures.callRequest.params._meta["ai.frontman/execution-context"].toolCallId, "tool-call-1")
})
