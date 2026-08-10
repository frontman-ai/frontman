import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv from "ajv"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {Tool} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const generatedSchema = await readJson(new URL("../schemas/mcp/tool.json", import.meta.url))
const oracle = createOracle(upstreamSchema)
const generatedAjv = new Ajv2020({strict: true})
addFormats(generatedAjv)
const validateGenerated = generatedAjv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))
const fixtureNames = [
  "with-default-2020-12-input-schema.json",
  "with-explicit-draft-07-input-schema.json",
  "with-no-parameters.json",
  "tool-with-composition-input-schema.json",
  "with-output-schema-for-structured-content.json",
  "tool-with-array-output-schema.json",
]
const officialFixtures = await Promise.all(
  fixtureNames.map(name => readJson(new URL(`mcp-upstream/examples/Tool/${name}`, import.meta.url))),
)

const compileSchema = schema => {
  let ajv
  switch (schema.$schema) {
    case undefined:
    case "https://json-schema.org/draft/2020-12/schema":
      ajv = new Ajv2020({strict: false})
      break
    case "http://json-schema.org/draft-07/schema#":
      ajv = new Ajv({strict: false})
      break
    default:
      throw new Error(`Unsupported official fixture dialect: ${schema.$schema}`)
  }
  addFormats(ajv)
  ajv.compile(schema)
}

const assertValid = fixture => {
  const parsed = S.parseOrThrow(fixture, Tool.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, Tool.schema, S.json))

  assert.deepEqual(encoded, fixture)
  assert.equal(oracle.validate("Tool", encoded).valid, true)
  assert.equal(validateGenerated(encoded), true)
}

const assertInvalid = fixture => {
  assert.throws(() => S.parseOrThrow(fixture, Tool.schema))
  assert.equal(oracle.validate("Tool", fixture).valid, false)
  assert.equal(validateGenerated(fixture), false)
}

test("official tool fixtures round-trip and contain valid declared schemas", () => {
  for (const fixture of officialFixtures) {
    assertValid(fixture)
    compileSchema(fixture.inputSchema)
    if (fixture.outputSchema !== undefined) {
      compileSchema(fixture.outputSchema)
    }
  }
})

test("complete tool metadata round-trips through the shared contract", () => {
  const fixture = {
    name: "project.search",
    title: "Project Search",
    description: "Search project files",
    inputSchema: {
      type: "object",
      properties: {query: {type: "string"}},
      required: ["query"],
    },
    outputSchema: {type: "array", items: {type: "string"}},
    icons: [{src: "https://frontman.sh/icon.png", mimeType: "image/png", theme: "dark"}],
    annotations: {
      title: "Search",
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
      readOnlyHint: true,
      "ai.frontman/hint": {scope: "project"},
    },
    _meta: {"ai.frontman/tool": {source: "browser"}},
  }

  assertValid(fixture)
  compileSchema(fixture.inputSchema)
  compileSchema(fixture.outputSchema)
})

test("tool contract requires name and object-rooted input schema", () => {
  const minimal = {name: "search", inputSchema: {type: "object"}}

  for (const field of ["name", "inputSchema"]) {
    const {[field]: _removed, ...fixture} = minimal
    assertInvalid(fixture)
  }

  for (const fixture of [
    {...minimal, name: 1},
    {...minimal, inputSchema: null},
    {...minimal, inputSchema: []},
    {...minimal, inputSchema: {}},
    {...minimal, inputSchema: {type: "array"}},
  ]) {
    assertInvalid(fixture)
  }
})

test("tool contract rejects malformed optional standard fields", () => {
  const minimal = {name: "search", inputSchema: {type: "object"}}

  for (const fixture of [
    {...minimal, title: 1},
    {...minimal, description: []},
    {...minimal, outputSchema: null},
    {...minimal, outputSchema: []},
    {...minimal, icons: [{}]},
    {...minimal, annotations: []},
    {...minimal, annotations: {readOnlyHint: "yes"}},
    {...minimal, _meta: null},
  ]) {
    assertInvalid(fixture)
  }
})

test("tool names retain the upstream string domain", () => {
  for (const name of ["", "x".repeat(129), "contains spaces"]) {
    assertValid({name, inputSchema: {type: "object"}})
  }
})
