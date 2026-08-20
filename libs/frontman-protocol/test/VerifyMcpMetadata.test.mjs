import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import * as S from "sury/src/S.res.mjs"
import * as Metadata from "../src/FrontmanProtocol__MCPMetadata.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = JSON.parse(await readFile(new URL("../schemas/mcp/metaObject.json", import.meta.url)))
const oracle = createOracle(upstreamSchema)
const validateGenerated = new Ajv2020({strict: true}).compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const validKeys = [
  "",
  "progressToken",
  "io.modelcontextprotocol/protocolVersion",
  "ai.frontman/execution-context",
  "a/",
  "a.b-c/name_with.dots-and-hyphens",
]

const invalidKeys = [
  "/name",
  "1.example/name",
  "example.-bad/name",
  "example.bad-/name",
  "example..bad/name",
  "example/name/again",
  "-name",
  "name-",
  "name with spaces",
  "name\n",
  "name\r",
  "name\u2028",
  "name\u2029",
]

test("metadata preserves valid keys and arbitrary JSON values", () => {
  const fixture = Object.fromEntries(validKeys.map((key, index) => [key, {index, value: [null, true, "text"]}]))
  const parsed = S.parseOrThrow(fixture, Metadata.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, Metadata.schema, S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate("MetaObject", encoded).valid, true)
  assert.equal(validateGenerated(encoded), true)
})

test("metadata rejects reserved trace propagation fields", () => {
  for (const key of ["traceparent", "tracestate", "baggage"]) {
    assert.throws(() => S.parseOrThrow({[key]: "must-not-propagate"}, Metadata.schema))
    assert.equal(validateGenerated({[key]: "must-not-propagate"}), false)
  }
})

test("metadata rejects keys outside the normative grammar", () => {
  for (const key of invalidKeys) {
    assert.throws(() => S.parseOrThrow({[key]: true}, Metadata.schema))
    assert.equal(validateGenerated({[key]: true}), false)
  }
})

test("metadata accepts 64 immediate keys and rejects 65", () => {
  const fixture = Object.fromEntries(Array.from({length: 64}, (_, index) => [`com.example/key-${index}`, index]))

  assert.deepEqual(S.parseOrThrow(fixture, Metadata.schema), fixture)
  assert.throws(() => S.parseOrThrow({...fixture, "com.example/key-64": 64}, Metadata.schema))
  assert.equal(validateGenerated(fixture), true)
  assert.equal(validateGenerated({...fixture, "com.example/key-64": 64}), false)
})

test("metadata enforces the compact UTF-8 byte limit", () => {
  const prefix = Buffer.byteLength(JSON.stringify({"com.example/data": ""}))
  const atLimit = {"com.example/data": "x".repeat(Metadata.maxBytes - prefix)}
  const overLimit = {"com.example/data": "x".repeat(Metadata.maxBytes - prefix + 1)}

  assert.equal(Buffer.byteLength(JSON.stringify(atLimit)), Metadata.maxBytes)
  assert.deepEqual(S.parseOrThrow(atLimit, Metadata.schema), atLimit)
  assert.throws(() => S.parseOrThrow(overLimit, Metadata.schema))
  assert.throws(() => S.parseOrThrow({"com.example/data": "é".repeat(Metadata.maxBytes / 2)}, Metadata.schema))
})
