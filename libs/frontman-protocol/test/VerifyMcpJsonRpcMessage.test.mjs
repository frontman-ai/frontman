import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {Wire} from "../src/FrontmanProtocol__JsonRpc.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const fixtures = {
  request: await readJson(
    new URL("mcp-upstream/examples/CallToolRequest/call-tool-request.json", import.meta.url),
  ),
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
}
const requestGeneratedSchema = generatedSchema("mcp/jsonRpcRequest")
const messageGeneratedSchema = generatedSchema("mcp/jsonRpcMessage")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGeneratedRequest = ajv.compile(requestGeneratedSchema)
const validateGeneratedMessage = ajv.compile(messageGeneratedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const roundTrip = (value, schema) => {
  const parsed = S.parseOrThrow(value, schema)
  return wireValue(S.decodeOrThrow(parsed, schema, S.json))
}

const accepts = (value, schema) => {
  try {
    S.parseOrThrow(value, schema)
    return true
  } catch {
    return false
  }
}

const assertValidRequest = value => {
  assert.deepEqual(roundTrip(value, Wire.requestSchema), value)
  assert.equal(oracle.validate("JSONRPCRequest", value).valid, true)
  assert.equal(validateGeneratedRequest(value), true)
}

const assertInvalidRequest = value => {
  assert.equal(accepts(value, Wire.requestSchema), false)
  assert.equal(oracle.validate("JSONRPCRequest", value).valid, false)
  assert.equal(validateGeneratedRequest(value), false)
}

const assertValidMessage = value => {
  assert.deepEqual(roundTrip(value, Wire.messageSchema), value)
  assert.equal(oracle.validate("JSONRPCMessage", value).valid, true)
  assert.equal(validateGeneratedMessage(value), true)
}

const assertInvalidMessage = value => {
  assert.equal(accepts(value, Wire.messageSchema), false)
  assert.equal(validateGeneratedMessage(value), false)
}

test("official JSON-RPC message classes round-trip and validate upstream", () => {
  assertValidRequest(fixtures.request)

  for (const fixture of Object.values(fixtures)) {
    assertValidMessage(fixture)
  }
})

test("generic requests preserve open fields, object params, and exact IDs", () => {
  for (const value of [
    {jsonrpc: "2.0", id: "", method: "", vendor: [null, true]},
    {jsonrpc: "2.0", id: Number.MIN_SAFE_INTEGER, method: "vendor/method"},
    {jsonrpc: "2.0", id: Number.MAX_SAFE_INTEGER, method: "vendor/method", params: {}},
    {
      jsonrpc: "2.0",
      id: -1,
      method: "vendor/method",
      params: {nested: [null, true, {value: 1.5}]},
      vendorEnvelope: {preserved: true},
    },
  ]) {
    assertValidRequest(value)
    assertValidMessage(value)
  }
})

test("generic requests reject unsafe numeric IDs accepted by upstream", () => {
  for (const id of [Number.MIN_SAFE_INTEGER - 1, Number.MAX_SAFE_INTEGER + 1]) {
    const value = {jsonrpc: "2.0", id, method: "vendor/method"}
    assert.equal(oracle.validate("JSONRPCRequest", value).valid, true)
    assert.equal(accepts(value, Wire.requestSchema), false)
    assert.equal(validateGeneratedRequest(value), false)
    assertInvalidMessage(value)
  }
})

test("generic requests require exact envelope fields and object params", () => {
  for (const field of ["jsonrpc", "id", "method"]) {
    const value = structuredClone(fixtures.request)
    delete value[field]
    assertInvalidRequest(value)
  }

  for (const value of [
    {...fixtures.request, jsonrpc: "1.0"},
    {...fixtures.request, id: null},
    {...fixtures.request, id: 1.5},
    {...fixtures.request, id: true},
    {...fixtures.request, method: 1},
    {...fixtures.request, params: null},
    {...fixtures.request, params: []},
    {...fixtures.request, params: "invalid"},
  ]) {
    assertInvalidRequest(value)
  }
})

test("generic message classes are mutually exclusive", () => {
  const classes = [Wire.requestSchema, Wire.notificationSchema, Wire.responseSchema]
  for (const fixture of Object.values(fixtures)) {
    assert.equal(classes.filter(schema => accepts(fixture, schema)).length, 1)
  }

  for (const value of [
    {...fixtures.request, result: {resultType: "complete"}},
    {...fixtures.request, error: {code: -32603, message: "mixed"}},
    {...fixtures.notification, result: {resultType: "complete"}},
    {...fixtures.resultResponse, method: "tools/call"},
    {...fixtures.errorResponse, method: "tools/call"},
  ]) {
    assert.equal(oracle.validate("JSONRPCMessage", value).valid, true)
    assertInvalidMessage(value)
  }
})

test("generic message schema rejects malformed and unclassified values", () => {
  for (const value of [
    null,
    [],
    {},
    {jsonrpc: "2.0"},
    {jsonrpc: "2.0", id: "request-1"},
    {jsonrpc: "2.0", method: 1},
    {jsonrpc: "2.0", id: "request-1", result: {}},
    {jsonrpc: "2.0", error: {code: -32603.5, message: "fractional"}},
  ]) {
    assertInvalidMessage(value)
  }
})
