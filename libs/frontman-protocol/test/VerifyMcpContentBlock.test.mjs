import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import * as S from "sury/src/S.res.mjs"
import * as ContentBlock from "../src/FrontmanProtocol__ContentBlock.res.mjs"
import {CallToolResult} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const oracle = createOracle(upstreamSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const contentFixtures = [
  ["TextContent", {
    type: "text",
    text: "hello",
    _meta: {"com.example/source": "test"},
    annotations: {audience: ["assistant", "user"], priority: 0.5, lastModified: "2026-08-08T00:00:00Z"},
  }],
  ["ImageContent", {type: "image", data: "aW1hZ2U=", mimeType: "image/png"}],
  ["AudioContent", {type: "audio", data: "YXVkaW8=", mimeType: "audio/mpeg"}],
  ["ResourceLink", {
    type: "resource_link",
    name: "report",
    uri: "file:///tmp/report.txt",
    title: "Report",
    description: "Generated report",
    mimeType: "text/plain",
    size: 2147483648,
    icons: [{src: "https://example.com/report.png", mimeType: "image/png", sizes: ["48x48"], theme: "dark"}],
  }],
  ["EmbeddedResource", {
    type: "resource",
    resource: {uri: "file:///tmp/report.txt", mimeType: "text/plain", text: "report", _meta: {"com.example/id": 1}},
  }],
  ["EmbeddedResource", {
    type: "resource",
    resource: {uri: "file:///tmp/report.bin", mimeType: "application/octet-stream", blob: "YmxvYg=="},
  }],
]

test("content blocks round-trip within their upstream definitions", () => {
  for (const [definition, fixture] of contentFixtures) {
    const parsed = S.parseOrThrow(fixture, ContentBlock.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, ContentBlock.schema, S.json))
    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate(definition, encoded).valid, true)
  }
})

test("content schemas reject invalid constrained values", () => {
  const fixtures = [
    {...contentFixtures[0][1], annotations: {audience: ["system"]}},
    {...contentFixtures[0][1], annotations: {priority: 1.1}},
    {...contentFixtures[3][1], size: 1.5},
    {...contentFixtures[3][1], icons: [{src: "https://example.com/icon.png", theme: "sepia"}]},
    {...contentFixtures[0][1], _meta: "not-an-object"},
    {...contentFixtures[1][1], data: "not-base64"},
    {...contentFixtures[3][1], uri: "not a URI"},
  ]

  for (const fixture of fixtures) {
    assert.throws(() => S.parseOrThrow(fixture, ContentBlock.schema))
    assert.equal(oracle.validate("ContentBlock", fixture).valid, false)
  }
})

test("structured content preserves every JSON value", () => {
  const values = [{value: 1}, [1, "two"], "text", 42, true, null]

  for (const structuredContent of values) {
    const fixture = {content: [], structuredContent, resultType: "complete"}
    const parsed = S.parseOrThrow(fixture, CallToolResult.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, CallToolResult.schema, S.json))
    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("CallToolResult", encoded).valid, true)
  }
})
