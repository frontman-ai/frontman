import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {InputResponses} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const generatedSchema = getGeneratedSchema("mcp/inputResponses")
const officialFixture = await readJson(
  new URL(
    "mcp-upstream/examples/InputResponses/elicitation-and-sampling-input-responses.json",
    import.meta.url,
  ),
)
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const assertValid = fixture => {
  const parsed = S.parseOrThrow(fixture, InputResponses.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, InputResponses.schema, S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate("InputResponses", encoded).valid, true)
  assert.equal(validateGenerated(encoded), true)
}

const assertInvalid = fixture => {
  assert.throws(() => S.parseOrThrow(fixture, InputResponses.schema))
  assert.equal(oracle.validate("InputResponses", fixture).valid, false)
  assert.equal(validateGenerated(fixture), false)
}

test("official input responses round-trip and validate upstream", () => {
  assertValid(officialFixture)
})

test("input responses preserve every permitted result type", async () => {
  const fixtureGroups = [
    ["ElicitResult", [
      "input-multiple-fields.json",
      "input-single-field.json",
      "accept-url-mode-no-content.json",
    ]],
    ["CreateMessageResult", ["text-response.json", "tool-use-response.json", "final-response.json"]],
    ["ListRootsResult", ["single-root-directory.json", "multiple-root-directories.json"]],
  ]

  for (const [definition, names] of fixtureGroups) {
    for (const name of names) {
      const value = await readJson(
        new URL(`mcp-upstream/examples/${definition}/${name}`, import.meta.url),
      )
      assertValid({response: value})
    }
  }
})

test("elicitation results preserve bounded form values", () => {
  assertValid({
    response: {
      action: "accept",
      content: {
        text: "value",
        integer: Number.MAX_SAFE_INTEGER,
        boolean: true,
        strings: ["one", "two"],
      },
    },
  })

  for (const content of [{value: 1.5}, {value: null}, {value: [1]}, {value: {nested: true}}]) {
    assertInvalid({response: {action: "accept", content}})
  }
})

test("sampling results reject malformed content and required fields", () => {
  const base = {
    role: "assistant",
    content: {type: "text", text: "hello"},
    model: "frontman-test",
  }

  for (const fixture of [
    {response: {...base, role: "system"}},
    {response: {...base, content: {type: "resource_link", name: "x", uri: "file:///x"}}},
    {response: {...base, content: {type: "tool_use", id: "1", name: "search", input: []}}},
    {response: {...base, content: {type: "tool_result", toolUseId: "1"}}},
    {response: {role: "assistant", content: base.content}},
  ]) {
    assertInvalid(fixture)
  }
})

test("roots and input-response maps reject malformed values", () => {
  assertValid({response: {roots: []}})

  for (const fixture of [
    null,
    [],
    {response: null},
    {response: {}},
    {response: {roots: {}}},
    {response: {roots: [{}]}},
    {response: {action: "unknown"}},
  ]) {
    assertInvalid(fixture)
  }
})

test("root URIs enforce the normative file scheme beyond the upstream generated schema", () => {
  assertValid({response: {roots: [{uri: "FILE:///project"}]}})

  for (const uri of ["https://example.com/project", "file:/project"]) {
    const fixture = {response: {roots: [{uri}]}}

    assert.throws(() => S.parseOrThrow(fixture, InputResponses.schema))
    assert.equal(validateGenerated(fixture), false)
  }

  const upstreamDiscrepancy = {response: {roots: [{uri: "https://example.com/project"}]}}
  assert.equal(oracle.validate("InputResponses", upstreamDiscrepancy).valid, true)
})
