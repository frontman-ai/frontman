import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  ElicitRequest,
  ElicitRequestFormParams,
  ElicitRequestURLParams,
  PrimitiveSchemaDefinition,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixtures = {
  ElicitRequest: await readJson(
    new URL("mcp-upstream/examples/ElicitRequest/elicitation-request.json", import.meta.url),
  ),
  ElicitRequestFormParams: await Promise.all(
    ["elicit-single-field.json", "elicit-multiple-fields.json"].map(name =>
      readJson(new URL(`mcp-upstream/examples/ElicitRequestFormParams/${name}`, import.meta.url)),
    ),
  ),
  ElicitRequestURLParams: await readJson(
    new URL(
      "mcp-upstream/examples/ElicitRequestURLParams/elicit-sensitive-data.json",
      import.meta.url,
    ),
  ),
}
const generatedSchemas = {
  ElicitRequest: generatedSchema("mcp/elicitRequest"),
  ElicitRequestFormParams: generatedSchema("mcp/elicitRequestFormParams"),
  ElicitRequestURLParams: generatedSchema("mcp/elicitRequestUrlParams"),
  PrimitiveSchemaDefinition: generatedSchema("mcp/primitiveSchemaDefinition"),
}
const schemas = {
  ElicitRequest: ElicitRequest.schema,
  ElicitRequestFormParams: ElicitRequestFormParams.schema,
  ElicitRequestURLParams: ElicitRequestURLParams.schema,
  PrimitiveSchemaDefinition: PrimitiveSchemaDefinition.schema,
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

test("official elicitation request fixtures round-trip and validate upstream", () => {
  assertValid("ElicitRequest", officialFixtures.ElicitRequest)
  for (const fixture of officialFixtures.ElicitRequestFormParams) {
    assertValid("ElicitRequestFormParams", fixture)
  }
  assertValid("ElicitRequestURLParams", officialFixtures.ElicitRequestURLParams)
})

test("elicitation form schemas preserve every primitive definition", () => {
  const definitions = [
    {
      type: "string",
      title: "Email",
      description: "Contact address",
      minLength: 1,
      maxLength: Number.MAX_SAFE_INTEGER,
      format: "email",
      default: "user@example.com",
    },
    {type: "number", minimum: 0.5, maximum: 100.5, default: 50.5},
    {type: "integer", minimum: -1, maximum: Number.MAX_SAFE_INTEGER, default: 1},
    {type: "boolean", default: false},
    {type: "string", enum: ["red", "green"], default: "red"},
    {
      type: "string",
      oneOf: [{const: "#f00", title: "Red"}],
      default: "#f00",
    },
    {
      type: "string",
      enum: ["red"],
      enumNames: ["Red"],
      default: "red",
    },
    {
      type: "array",
      items: {type: "string", enum: ["red", "green"]},
      minItems: 0,
      maxItems: Number.MAX_SAFE_INTEGER,
      default: ["red"],
    },
    {
      type: "array",
      items: {anyOf: [{const: "#f00", title: "Red"}]},
      default: ["#f00"],
    },
  ]

  for (const definition of definitions) {
    assertValid("PrimitiveSchemaDefinition", definition)
  }
})

test("elicitation form mode may be absent and preserves open fields", () => {
  assertValid("ElicitRequest", {
    method: "elicitation/create",
    params: {
      message: "Choose a value",
      requestedSchema: {
        $schema: "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {value: {type: "string"}},
      },
      vendorField: {preserved: true},
    },
    id: "nested-request-id",
  })
})

test("elicitation rejects malformed primitive and requested schemas", () => {
  for (const fixture of [
    {type: "object"},
    {type: "string", format: "hostname"},
    {type: "string", minLength: 1.5},
    {type: "integer", minimum: "0"},
    {type: "boolean", default: "false"},
    {type: "array", items: {type: "string"}},
  ]) {
    assertInvalid("PrimitiveSchemaDefinition", fixture)
  }

  const base = officialFixtures.ElicitRequestFormParams[0]
  for (const fixture of [
    {...base, message: 1},
    {...base, mode: "url"},
    {...base, requestedSchema: null},
    {...base, requestedSchema: {type: "object"}},
    {...base, requestedSchema: {properties: {}}},
    {...base, requestedSchema: {type: "array", properties: {}}},
    {...base, requestedSchema: {type: "object", properties: {nested: {type: "object"}}}},
  ]) {
    assertInvalid("ElicitRequestFormParams", fixture)
  }
})

test("elicitation enforces non-negative JSON Schema bounds beyond the upstream artifact", () => {
  for (const fixture of [
    {type: "string", minLength: -1},
    {type: "string", maxLength: -1},
    {type: "array", items: {type: "string", enum: []}, minItems: -1},
    {type: "array", items: {anyOf: []}, maxItems: -1},
  ]) {
    assert.throws(() => S.parseOrThrow(fixture, PrimitiveSchemaDefinition.schema))
    assert.equal(generatedValidators.PrimitiveSchemaDefinition(fixture), false)
    assert.equal(oracle.validate("PrimitiveSchemaDefinition", fixture).valid, true)
  }
})

test("elicitation requires exact request and URL mode shapes", () => {
  const urlBase = officialFixtures.ElicitRequestURLParams
  for (const fixture of [
    {...urlBase, mode: "form"},
    {...urlBase, message: 1},
    {...urlBase, url: "not a URI"},
    {mode: "url", message: "Missing URL"},
  ]) {
    assertInvalid("ElicitRequestURLParams", fixture)
  }

  for (const fixture of [
    {},
    {method: "roots/list", params: officialFixtures.ElicitRequest.params},
    {method: "elicitation/create"},
    {method: "elicitation/create", params: {}},
  ]) {
    assertInvalid("ElicitRequest", fixture)
  }
})
