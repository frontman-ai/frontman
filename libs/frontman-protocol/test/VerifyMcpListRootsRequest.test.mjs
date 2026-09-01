import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {ListRootsRequest} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixture = await readJson(
  new URL("mcp-upstream/examples/ListRootsRequest/list-roots-request.json", import.meta.url),
)
const generatedSchema = getGeneratedSchema("mcp/listRootsRequest")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const assertValid = fixture => {
  const parsed = S.parseOrThrow(fixture, ListRootsRequest.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, ListRootsRequest.schema, S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate("ListRootsRequest", encoded).valid, true)
  assert.equal(validateGenerated(encoded), true)
}

const assertInvalid = fixture => {
  assert.throws(() => S.parseOrThrow(fixture, ListRootsRequest.schema))
  assert.equal(oracle.validate("ListRootsRequest", fixture).valid, false)
  assert.equal(validateGenerated(fixture), false)
}

test("official roots/list request round-trips and validates upstream", () => {
  assertValid(officialFixture)
})

test("roots/list preserves optional metadata and open fields", () => {
  assertValid({method: "roots/list"})
  assertValid({method: "roots/list", params: {}})
  assertValid({
    method: "roots/list",
    params: {_meta: {"ai.frontman/request": {source: "test"}}},
    vendorField: [null, true, 1, "value"],
  })
})

test("roots/list requires the exact method and valid optional params", () => {
  for (const fixture of [
    {},
    {method: "sampling/createMessage"},
    {method: 1},
    {method: "roots/list", params: null},
    {method: "roots/list", params: []},
    {method: "roots/list", params: {_meta: []}},
  ]) {
    assertInvalid(fixture)
  }
})
