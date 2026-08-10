import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  DiscoverRequest,
  DiscoverResult,
  DiscoverResultResponse,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const requestFixture = await readJson(
  new URL("mcp-upstream/examples/DiscoverRequest/server-discover-request.json", import.meta.url),
)
const resultFixture = await readJson(
  new URL("mcp-upstream/examples/DiscoverResult/server-capabilities-discovery.json", import.meta.url),
)
const responseFixture = await readJson(
  new URL(
    "mcp-upstream/examples/DiscoverResultResponse/discover-result-response.json",
    import.meta.url,
  ),
)
const generatedSchemas = {
  DiscoverRequest: await readJson(new URL("../schemas/mcp/discoverRequest.json", import.meta.url)),
  DiscoverResult: await readJson(new URL("../schemas/mcp/discoverResult.json", import.meta.url)),
  DiscoverResultResponse: await readJson(
    new URL("../schemas/mcp/discoverResultResponse.json", import.meta.url),
  ),
}
const schemas = {
  DiscoverRequest: DiscoverRequest.schema,
  DiscoverResult: DiscoverResult.schema,
  DiscoverResultResponse: DiscoverResultResponse.schema,
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
  assert.equal(generatedValidators[name](fixture), false)
  assert.equal(oracle.validate(name, fixture).valid, false)
}

test("official discovery fixtures round-trip and validate upstream", () => {
  assertValid("DiscoverRequest", requestFixture)
  assertValid("DiscoverResult", resultFixture)
  assertValid("DiscoverResultResponse", responseFixture)
})

test("discovery request requires its exact envelope and request metadata", () => {
  for (const field of ["jsonrpc", "id", "method", "params"]) {
    const {[field]: _removed, ...fixture} = requestFixture
    assertInvalid("DiscoverRequest", fixture)
  }

  const {_meta: _removed, ...params} = requestFixture.params
  assertInvalid("DiscoverRequest", {...requestFixture, params})

  for (const fixture of [
    {...requestFixture, jsonrpc: "1.0"},
    {...requestFixture, id: null},
    {...requestFixture, method: "tools/list"},
    {...requestFixture, params: []},
    {...requestFixture, params: {...requestFixture.params, _meta: null}},
  ]) {
    assertInvalid("DiscoverRequest", fixture)
  }
})

test("discovery result requires complete capabilities and cache fields", () => {
  for (const field of ["resultType", "supportedVersions", "capabilities", "ttlMs", "cacheScope"]) {
    const {[field]: _removed, ...fixture} = resultFixture
    assertInvalid("DiscoverResult", fixture)
  }

  for (const fixture of [
    {...resultFixture, supportedVersions: "2026-07-28"},
    {...resultFixture, capabilities: []},
    {...resultFixture, resultType: 1},
    {...resultFixture, ttlMs: -1},
    {...resultFixture, ttlMs: 1.5},
    {...resultFixture, cacheScope: "shared"},
    {...resultFixture, instructions: 1},
    {...resultFixture, _meta: null},
  ]) {
    assertInvalid("DiscoverResult", fixture)
  }
})

test("discovery result accepts open result types, both cache scopes, and valid TTL values", () => {
  for (const resultType of ["input_required", "com.example/custom-result"]) {
    assertValid("DiscoverResult", {...resultFixture, resultType})
  }

  for (const cacheScope of ["private", "public"]) {
    for (const ttlMs of [0, 1, Number.MAX_SAFE_INTEGER]) {
      assertValid("DiscoverResult", {...resultFixture, cacheScope, ttlMs})
    }
  }
})

test("discovery response requires the exact success envelope", () => {
  for (const field of ["jsonrpc", "id", "result"]) {
    const {[field]: _removed, ...fixture} = responseFixture
    assertInvalid("DiscoverResultResponse", fixture)
  }

  for (const fixture of [
    {...responseFixture, jsonrpc: "1.0"},
    {...responseFixture, id: null},
    {...responseFixture, result: null},
  ]) {
    assertInvalid("DiscoverResultResponse", fixture)
  }
})
