import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import * as S from "sury/src/S.res.mjs"
import {ClientCapabilities} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = getGeneratedSchema("mcp/clientCapabilities")
const oracle = createOracle(upstreamSchema)
const validateGenerated = new Ajv2020({strict: true}).compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const fixtures = [
  {},
  {
    elicitation: {form: {types: ["string"]}, url: {}},
    experimental: {"com.example/preview": {enabled: true}},
    extensions: {"ai.frontman/execution-context": {version: 1}},
    roots: {},
    sampling: {context: {supported: true}, tools: {}},
    "com.example/custom-capability": [1, null, {mode: "custom"}],
  },
]

test("client capabilities preserve known and unknown capabilities", () => {
  for (const fixture of fixtures) {
    const parsed = S.parseOrThrow(fixture, ClientCapabilities.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, ClientCapabilities.schema, S.json))

    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("ClientCapabilities", encoded).valid, true)
    assert.equal(validateGenerated(encoded), true)
  }
})

test("client capabilities reject malformed known fields", () => {
  const invalid = [
    {elicitation: false},
    {elicitation: {form: []}},
    {experimental: {preview: []}},
    {extensions: {"com.example/extension": []}},
    {roots: []},
    {sampling: "enabled"},
    {sampling: {context: []}},
    {sampling: {tools: null}},
  ]

  for (const fixture of invalid) {
    assert.throws(() => S.parseOrThrow(fixture, ClientCapabilities.schema))
    assert.equal(oracle.validate("ClientCapabilities", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})

test("client capability extensions enforce normative identifier grammar", () => {
  const fixture = {extensions: {unprefixed: {}}}

  assert.throws(() => S.parseOrThrow(fixture, ClientCapabilities.schema))
  assert.equal(validateGenerated(fixture), false)
})
