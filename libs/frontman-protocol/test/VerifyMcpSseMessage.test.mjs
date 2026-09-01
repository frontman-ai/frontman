import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {StreamableHttpSseMessage} from "../src/FrontmanProtocol__MCP.res.mjs"
import {Wire} from "../src/FrontmanProtocol__JsonRpc.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixtures = {
  notification: await readJson(
    new URL("mcp-upstream/examples/ProgressNotification/progress-message.json", import.meta.url),
  ),
  resultResponse: await readJson(
    new URL(
      "mcp-upstream/examples/CallToolResultResponse/call-tool-result-response.json",
      import.meta.url,
    ),
  ),
  errorResponse: await readJson(
    new URL("mcp-upstream/examples/HeaderMismatchError/header-mismatch.json", import.meta.url),
  ),
  request: await readJson(
    new URL("mcp-upstream/examples/CallToolRequest/call-tool-request.json", import.meta.url),
  ),
}
const generatedSchema = getGeneratedSchema("mcp/streamableHttpSseMessage")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const assertValid = (fixture, definition) => {
  const parsed = S.parseOrThrow(fixture, StreamableHttpSseMessage.schema)
  const encoded = wireValue(
    S.decodeOrThrow(parsed, StreamableHttpSseMessage.schema, S.json),
  )

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate(definition, encoded).valid, true)
  assert.equal(validateGenerated(encoded), true)
}

const assertInvalid = fixture => {
  assert.throws(() => S.parseOrThrow(fixture, StreamableHttpSseMessage.schema))
  assert.equal(validateGenerated(fixture), false)
}

test("official notification and response fixtures are accepted SSE messages", () => {
  assertValid(officialFixtures.notification, "JSONRPCNotification")
  assertValid(officialFixtures.resultResponse, "JSONRPCResultResponse")
  assertValid(officialFixtures.errorResponse, "JSONRPCErrorResponse")
})

test("accepted SSE messages preserve open fields and wide IDs and error codes", () => {
  assertValid(
    {
      jsonrpc: "2.0",
      method: "notifications/vendor",
      params: {vendorParam: [true, 1, "value"]},
      vendorEnvelope: {preserved: true},
    },
    "JSONRPCNotification",
  )
  assertValid(
    {
      jsonrpc: "2.0",
      id: Number.MAX_SAFE_INTEGER,
      result: {resultType: "vendor/result", vendorResult: [null, true]},
      vendorEnvelope: "preserved",
    },
    "JSONRPCResultResponse",
  )
  assertValid(
    {
      jsonrpc: "2.0",
      error: {
        code: Number.MAX_SAFE_INTEGER,
        message: "Transport error",
        data: [null, true, {nested: "value"}],
        vendorError: "preserved",
      },
      vendorEnvelope: "preserved",
    },
    "JSONRPCErrorResponse",
  )
})

test("accepted SSE messages reject independent requests", () => {
  assert.equal(oracle.validate("JSONRPCRequest", officialFixtures.request).valid, true)
  assertInvalid(officialFixtures.request)
})

test("accepted SSE messages reject malformed and mixed envelopes", () => {
  for (const fixture of [
    null,
    [],
    {},
    {jsonrpc: "1.0", method: "notifications/progress"},
    {jsonrpc: "2.0", method: "notifications/progress", id: "request-1"},
    {jsonrpc: "2.0", method: "notifications/progress", params: []},
    {jsonrpc: "2.0", id: "request-1", result: {}},
    {jsonrpc: "2.0", id: null, result: {resultType: "complete"}},
    {
      jsonrpc: "2.0",
      id: "request-1",
      result: {resultType: "complete"},
      error: {code: -32603, message: "mixed"},
    },
    {jsonrpc: "2.0", error: {code: -32603.5, message: "fractional"}},
    {jsonrpc: "2.0", error: {code: -32603}},
    {jsonrpc: "2.0", error: {code: -32603, message: 1}},
    {
      jsonrpc: "2.0",
      id: "request-1",
      method: "tools/call",
      result: {resultType: "complete"},
    },
  ]) {
    assertInvalid(fixture)
  }
})

test("wire response schemas classify result and error envelopes exclusively", () => {
  assert.doesNotThrow(() => S.parseOrThrow(officialFixtures.resultResponse, Wire.responseSchema))
  assert.doesNotThrow(() => S.parseOrThrow(officialFixtures.errorResponse, Wire.responseSchema))
  assert.throws(() =>
    S.parseOrThrow(
      {
        ...officialFixtures.resultResponse,
        error: {code: -32603, message: "mixed"},
      },
      Wire.responseSchema,
    )
  )
})
