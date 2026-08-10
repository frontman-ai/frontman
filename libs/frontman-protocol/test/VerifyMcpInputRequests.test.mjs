import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {InputRequests, InputRequiredResult} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixtures = {
  InputRequests: await readJson(
    new URL(
      "mcp-upstream/examples/InputRequests/elicitation-and-sampling-input-requests.json",
      import.meta.url,
    ),
  ),
  InputRequiredResult: await Promise.all(
    [
      "input-required-result-with-elicitation-and-sampling-and-request-state.json",
      "input-required-result-with-request-state-only.json",
    ].map(name =>
      readJson(
        new URL(`mcp-upstream/examples/InputRequiredResult/${name}`, import.meta.url),
      ),
    ),
  ),
  ListRootsRequest: await readJson(
    new URL("mcp-upstream/examples/ListRootsRequest/list-roots-request.json", import.meta.url),
  ),
}
const generatedSchemas = {
  InputRequests: await readJson(new URL("../schemas/mcp/inputRequests.json", import.meta.url)),
  InputRequiredResult: await readJson(
    new URL("../schemas/mcp/inputRequiredResult.json", import.meta.url),
  ),
}
const schemas = {
  InputRequests: InputRequests.schema,
  InputRequiredResult: InputRequiredResult.schema,
}
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const generatedValidators = Object.fromEntries(
  Object.entries(generatedSchemas).map(([name, schema]) => [name, ajv.compile(schema)]),
)
const wireValue = value => JSON.parse(JSON.stringify(value))

const assertValid = (name, fixture) => {
  const parsed = S.parseOrThrow(fixture, schemas[name])
  const encoded = wireValue(S.decodeOrThrow(parsed, schemas[name], S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate(name, encoded).valid, true)
  assert.equal(generatedValidators[name](encoded), true)
}

const assertInvalid = (name, fixture) => {
  assert.throws(() => S.parseOrThrow(fixture, schemas[name]))
  assert.equal(oracle.validate(name, fixture).valid, false)
  assert.equal(generatedValidators[name](fixture), false)
}

test("official input request and input-required fixtures round-trip and validate upstream", () => {
  assertValid("InputRequests", officialFixtures.InputRequests)
  for (const fixture of officialFixtures.InputRequiredResult) {
    assertValid("InputRequiredResult", fixture)
  }
})

test("input request maps accept exactly the three standard nested request variants", () => {
  assertValid("InputRequests", {})
  assertValid("InputRequests", {
    ...officialFixtures.InputRequests,
    roots: {...officialFixtures.ListRootsRequest, vendorRequestField: {preserved: true}},
  })

  for (const fixture of [
    null,
    [],
    {request: null},
    {request: {}},
    {request: {method: "resources/read", params: {}}},
    {request: {method: "roots/list", params: {_meta: []}}},
    {request: {method: "elicitation/create", params: {message: "Missing schema"}}},
    {request: {method: "sampling/createMessage", params: {messages: [], maxTokens: 1.5}}},
  ]) {
    assertInvalid("InputRequests", fixture)
  }
})

test("input-required results preserve open fields, metadata, and opaque state", () => {
  assertValid("InputRequiredResult", {
    resultType: "input_required",
    inputRequests: {},
    _meta: {
      "io.modelcontextprotocol/serverInfo": {name: "frontman-test", version: "1.0.0"},
      "example.com/result": {nested: [true, 1, "value"]},
    },
    vendorResultField: {preserved: true},
  })
  assertValid("InputRequiredResult", {
    resultType: "input_required",
    requestState: "opaque:not-decoded-or-normalized",
  })
})

test("input-required results reject malformed fields and nested requests", () => {
  for (const fixture of [
    null,
    [],
    {resultType: "input_required", inputRequests: null},
    {resultType: "input_required", requestState: 1},
    {resultType: "input_required", requestState: "state", _meta: []},
    {
      resultType: "input_required",
      inputRequests: {request: {method: "unknown", params: {}}},
    },
  ]) {
    assertInvalid("InputRequiredResult", fixture)
  }
})

test("runtime and generated schemas enforce normative input-required semantics", () => {
  for (const fixture of [
    {resultType: "input_required"},
    {resultType: "complete", requestState: "state"},
  ]) {
    assert.throws(() => S.parseOrThrow(fixture, InputRequiredResult.schema))
    assert.equal(generatedValidators.InputRequiredResult(fixture), false)
    assert.equal(oracle.validate("InputRequiredResult", fixture).valid, true)
  }
})
