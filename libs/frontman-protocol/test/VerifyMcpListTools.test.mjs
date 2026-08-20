import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  ListToolsRequest,
  ListToolsResult,
  ListToolsResultResponse,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const requestFixture = await readJson(
  new URL("mcp-upstream/examples/ListToolsRequest/list-tools-request.json", import.meta.url),
)
const resultFixture = await readJson(
  new URL(
    "mcp-upstream/examples/ListToolsResult/tools-list-with-cursor-and-ttl.json",
    import.meta.url,
  ),
)
const responseFixture = await readJson(
  new URL(
    "mcp-upstream/examples/ListToolsResultResponse/list-tools-result-response.json",
    import.meta.url,
  ),
)
const generatedSchemas = {
  ListToolsRequest: generatedSchema("mcp/listToolsRequest"),
  ListToolsResult: generatedSchema("mcp/listToolsResult"),
  ListToolsResultResponse: generatedSchema("mcp/listToolsResultResponse"),
}
const schemas = {
  ListToolsRequest: ListToolsRequest.schema,
  ListToolsResult: ListToolsResult.schema,
  ListToolsResultResponse: ListToolsResultResponse.schema,
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

test("official tools/list fixtures round-trip and validate upstream", () => {
  assertValid("ListToolsRequest", requestFixture)
  assertValid("ListToolsResult", resultFixture)
  assertValid("ListToolsResultResponse", responseFixture)
})

test("tools/list request requires its exact envelope and metadata shape", () => {
  for (const field of ["jsonrpc", "id", "method", "params"]) {
    const {[field]: _removed, ...fixture} = requestFixture
    assertInvalid("ListToolsRequest", fixture)
  }

  const {_meta: _removed, ...params} = requestFixture.params
  assertInvalid("ListToolsRequest", {...requestFixture, params})

  for (const fixture of [
    {...requestFixture, jsonrpc: "1.0"},
    {...requestFixture, id: null},
    {...requestFixture, method: "server/discover"},
    {...requestFixture, params: []},
    {...requestFixture, params: {...requestFixture.params, cursor: 1}},
  ]) {
    assertInvalid("ListToolsRequest", fixture)
  }
})

test("tools/list request preserves absent, empty, and opaque cursors", () => {
  for (const cursor of ["", "next-page", "eyJwYWdlIjoyfQ=="]) {
    assertValid("ListToolsRequest", {
      ...requestFixture,
      params: {...requestFixture.params, cursor},
    })
  }
})

test("tools/list result requires tools and cache fields", () => {
  for (const field of ["resultType", "tools", "ttlMs", "cacheScope"]) {
    const {[field]: _removed, ...fixture} = resultFixture
    assertInvalid("ListToolsResult", fixture)
  }

  for (const fixture of [
    {...resultFixture, resultType: 1},
    {...resultFixture, tools: {}},
    {...resultFixture, tools: [{}]},
    {...resultFixture, nextCursor: 1},
    {...resultFixture, ttlMs: -1},
    {...resultFixture, ttlMs: 1.5},
    {...resultFixture, cacheScope: "shared"},
    {...resultFixture, _meta: null},
  ]) {
    assertInvalid("ListToolsResult", fixture)
  }
})

test("tools/list result preserves empty catalogs, cursors, metadata, and cache boundaries", () => {
  const base = {
    resultType: "complete",
    tools: [],
    ttlMs: 0,
    cacheScope: "private",
    _meta: {"ai.frontman/catalog": {source: "browser"}},
  }

  assertValid("ListToolsResult", base)
  assertValid("ListToolsResult", {...base, nextCursor: ""})
  assertValid("ListToolsResult", {...base, ttlMs: Number.MAX_SAFE_INTEGER, cacheScope: "public"})
  assertValid("ListToolsResult", {...base, resultType: "input_required"})
  assertValid("ListToolsResult", {...base, resultType: "com.example/custom-result"})
})

test("tools/list success response requires its exact envelope", () => {
  for (const field of ["jsonrpc", "id", "result"]) {
    const {[field]: _removed, ...fixture} = responseFixture
    assertInvalid("ListToolsResultResponse", fixture)
  }

  for (const fixture of [
    {...responseFixture, jsonrpc: "1.0"},
    {...responseFixture, id: null},
    {...responseFixture, result: null},
  ]) {
    assertInvalid("ListToolsResultResponse", fixture)
  }
})
