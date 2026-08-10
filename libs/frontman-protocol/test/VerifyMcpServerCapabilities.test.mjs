import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import * as S from "sury/src/S.res.mjs"
import {ServerCapabilities} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = JSON.parse(await readFile(new URL("../schemas/mcp/serverCapabilities.json", import.meta.url)))
const oracle = createOracle(upstreamSchema)
const validateGenerated = new Ajv2020({strict: true}).compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const fixtures = [
  {},
  {
    completions: {},
    experimental: {"com.example/preview": {enabled: true}},
    extensions: {"ai.frontman/execution-context": {version: 1}},
    logging: {structured: true},
    prompts: {listChanged: false},
    resources: {listChanged: true, subscribe: false},
    tools: {listChanged: false},
    "com.example/custom-capability": [1, null, {mode: "custom"}],
  },
]

test("server capabilities preserve known and unknown capabilities", () => {
  for (const fixture of fixtures) {
    const parsed = S.parseOrThrow(fixture, ServerCapabilities.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, ServerCapabilities.schema, S.json))

    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("ServerCapabilities", encoded).valid, true)
    assert.equal(validateGenerated(encoded), true)
  }
})

test("server capabilities reject malformed known fields", () => {
  const invalid = [
    {completions: []},
    {experimental: {preview: []}},
    {extensions: {"com.example/extension": []}},
    {logging: true},
    {prompts: {listChanged: "yes"}},
    {resources: {listChanged: 1}},
    {resources: {subscribe: "yes"}},
    {tools: []},
    {tools: {listChanged: null}},
  ]

  for (const fixture of invalid) {
    assert.throws(() => S.parseOrThrow(fixture, ServerCapabilities.schema))
    assert.equal(oracle.validate("ServerCapabilities", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})

test("server capability extensions enforce normative identifier grammar", () => {
  const fixture = {extensions: {unprefixed: {}}}

  assert.throws(() => S.parseOrThrow(fixture, ServerCapabilities.schema))
  assert.equal(validateGenerated(fixture), false)
})
