import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  CallToolRequest,
  CallToolRequestParams,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const requestFixture = await readJson(
  new URL("mcp-upstream/examples/CallToolRequest/call-tool-request.json", import.meta.url),
)
const paramsFixtures = await Promise.all(
  ["get-weather-tool-call-params.json", "tool-call-params-with-progress-token.json"].map(name =>
    readJson(new URL(`mcp-upstream/examples/CallToolRequestParams/${name}`, import.meta.url)),
  ),
)
const generatedSchemas = {
  CallToolRequest: generatedSchema("mcp/callToolRequest"),
  CallToolRequestParams: generatedSchema("mcp/callToolRequestParams"),
}
const schemas = {
  CallToolRequest: CallToolRequest.schema,
  CallToolRequestParams: CallToolRequestParams.schema,
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

test("official tools/call fixtures round-trip and validate upstream", () => {
  assertValid("CallToolRequest", requestFixture)
  for (const fixture of paramsFixtures) {
    assertValid("CallToolRequestParams", fixture)
  }
})

test("tools/call requires its exact envelope, metadata, and tool name", () => {
  for (const field of ["jsonrpc", "id", "method", "params"]) {
    const {[field]: _removed, ...fixture} = requestFixture
    assertInvalid("CallToolRequest", fixture)
  }

  for (const field of ["_meta", "name"]) {
    const {[field]: _removed, ...params} = requestFixture.params
    assertInvalid("CallToolRequest", {...requestFixture, params})
  }

  for (const fixture of [
    {...requestFixture, jsonrpc: "1.0"},
    {...requestFixture, id: null},
    {...requestFixture, method: "tools/list"},
    {...requestFixture, params: []},
    {...requestFixture, params: {...requestFixture.params, _meta: []}},
    {...requestFixture, params: {...requestFixture.params, name: 1}},
    {...requestFixture, params: {...requestFixture.params, arguments: []}},
    {...requestFixture, params: {...requestFixture.params, arguments: null}},
    {...requestFixture, params: {...requestFixture.params, inputResponses: []}},
    {...requestFixture, params: {...requestFixture.params, requestState: {}}},
  ]) {
    assertInvalid("CallToolRequest", fixture)
  }
})

test("tools/call preserves standard initial and retry parameter domains", () => {
  const base = {
    ...requestFixture,
    id: Number.MAX_SAFE_INTEGER,
    params: {
      _meta: requestFixture.params._meta,
      name: "get_weather",
    },
  }

  assertValid("CallToolRequest", base)
  assertValid("CallToolRequest", {...base, params: {...base.params, arguments: {}}})
  assertValid("CallToolRequest", {
    ...base,
    params: {
      ...base.params,
      arguments: {nested: [null, true, 1, "value"]},
      inputResponses: {
        github_login: {
          action: "accept",
          content: {name: "octocat"},
        },
      },
      requestState: "",
    },
  })
})

test("tools/call has no declared private callId and retains upstream object openness", () => {
  const definition = generatedSchemas.CallToolRequestParams.$defs["mcp/callToolRequestParams"]
  assert.equal(definition.required.includes("callId"), false)
  assert.equal(Object.hasOwn(definition.properties, "callId"), false)

  const fixture = {
    ...requestFixture,
    "ai.frontman/envelope": true,
    params: {...requestFixture.params, callId: "legacy-extra"},
  }

  S.parseOrThrow(fixture, CallToolRequest.schema)
  assert.equal(oracle.validate("CallToolRequest", fixture).valid, true)
  assert.equal(generatedValidators.CallToolRequest(fixture), true)
})
