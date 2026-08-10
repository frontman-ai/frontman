import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import * as S from "sury/src/S.res.mjs"
import {Extensions} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = JSON.parse(await readFile(new URL("../schemas/mcp/extensions.json", import.meta.url)))
const oracle = createOracle(upstreamSchema)
const validateGenerated = new Ajv2020({strict: true}).compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const fixture = {
  "io.modelcontextprotocol/tasks": {},
  "ai.frontman/execution-context": {version: 1},
  "com.example.mcp/settings": {nested: {enabled: true}, values: [1, "two"]},
  "a/": {},
}

test("extension settings round-trip within client and server capability definitions", () => {
  const parsed = S.parseOrThrow(fixture, Extensions.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, Extensions.schema, S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate("ClientCapabilities", {extensions: encoded}).valid, true)
  assert.equal(oracle.validate("ServerCapabilities", {extensions: encoded}).valid, true)
  assert.equal(validateGenerated(encoded), true)
})

test("extension settings preserve every JSONValue declared by the authoritative type", () => {
  for (const value of [
    {"com.example/settings": {fraction: 1.5}},
    {"com.example/settings": {nullable: null}},
  ]) {
    const parsed = S.parseOrThrow(value, Extensions.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, Extensions.schema, S.json))

    assert.deepEqual(encoded, value)
    assert.equal(validateGenerated(encoded), true)
    assert.equal(oracle.validate("ClientCapabilities", {extensions: encoded}).valid, false)
    assert.equal(oracle.validate("ServerCapabilities", {extensions: encoded}).valid, false)
  }
})

test("extension identifiers require a valid metadata prefix", () => {
  const invalid = [
    "extension",
    "/extension",
    "1.example/extension",
    "example.-bad/extension",
    "example.bad-/extension",
    "example..bad/extension",
    "example/extension/again",
    "example/-extension",
    "example/extension-",
    "example/extension\n",
  ]

  for (const identifier of invalid) {
    const value = {[identifier]: {}}
    assert.throws(() => S.parseOrThrow(value, Extensions.schema))
    assert.equal(validateGenerated(value), false)
  }
})

test("extension settings must be JSON objects", () => {
  const invalid = [null, true, "settings", 1, []]

  for (const settings of invalid) {
    const value = {"com.example/extension": settings}
    assert.throws(() => S.parseOrThrow(value, Extensions.schema))
    assert.equal(oracle.validate("ClientCapabilities", {extensions: value}).valid, false)
    assert.equal(validateGenerated(value), false)
  }
})
