import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  CreateMessageRequest,
  CreateMessageRequestParams,
  ModelHint,
  ModelPreferences,
  SamplingMessage,
  ToolChoice,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixtures = {
  CreateMessageRequest: await readJson(
    new URL("mcp-upstream/examples/CreateMessageRequest/sampling-request.json", import.meta.url),
  ),
  CreateMessageRequestParams: await Promise.all(
    ["basic-request.json", "request-with-tools.json", "follow-up-with-tool-results.json"].map(
      name =>
        readJson(
          new URL(`mcp-upstream/examples/CreateMessageRequestParams/${name}`, import.meta.url),
        ),
    ),
  ),
  ModelPreferences: await readJson(
    new URL(
      "mcp-upstream/examples/ModelPreferences/with-hints-and-priorities.json",
      import.meta.url,
    ),
  ),
  SamplingMessage: await Promise.all(
    ["single-content-block.json", "multiple-content-blocks.json"].map(name =>
      readJson(new URL(`mcp-upstream/examples/SamplingMessage/${name}`, import.meta.url)),
    ),
  ),
}
const generatedSchemas = {
  CreateMessageRequest: generatedSchema("mcp/createMessageRequest"),
  CreateMessageRequestParams: generatedSchema("mcp/createMessageRequestParams"),
  ModelPreferences: generatedSchema("mcp/modelPreferences"),
  ModelHint: generatedSchema("mcp/modelHint"),
  SamplingMessage: generatedSchema("mcp/samplingMessage"),
  ToolChoice: generatedSchema("mcp/toolChoice"),
}
const schemas = {
  CreateMessageRequest: CreateMessageRequest.schema,
  CreateMessageRequestParams: CreateMessageRequestParams.schema,
  ModelHint: ModelHint.schema,
  ModelPreferences: ModelPreferences.schema,
  SamplingMessage: SamplingMessage.schema,
  ToolChoice: ToolChoice.schema,
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

test("official sampling request fixtures round-trip and validate upstream", () => {
  assertValid("CreateMessageRequest", officialFixtures.CreateMessageRequest)
  for (const fixture of officialFixtures.CreateMessageRequestParams) {
    assertValid("CreateMessageRequestParams", fixture)
  }
  assertValid("ModelPreferences", officialFixtures.ModelPreferences)
  for (const fixture of officialFixtures.SamplingMessage) {
    assertValid("SamplingMessage", fixture)
  }
})

test("sampling parameters preserve standard optional domains and open fields", () => {
  const base = {
    messages: [{role: "user", content: {type: "text", text: "Hello"}}],
    maxTokens: Number.MAX_SAFE_INTEGER,
  }

  assertValid("CreateMessageRequestParams", base)
  assertValid("CreateMessageRequestParams", {
    ...base,
    modelPreferences: {
      hints: [{name: "sonnet", vendorHint: true}, {}],
      costPriority: 0,
      intelligencePriority: 1,
      speedPriority: 0.5,
    },
    systemPrompt: "System",
    includeContext: "none",
    temperature: 0.25,
    stopSequences: [],
    metadata: {provider: {nested: [true, 1, "value"]}},
    toolChoice: {},
    vendorField: "preserved",
  })

  for (const mode of ["auto", "required", "none"]) {
    assertValid("ToolChoice", {mode, vendorChoice: true})
  }
  assertValid("ModelHint", {name: "sonnet", vendorHint: {weight: 2}})
  assertValid("ModelHint", {vendorHint: true})
  assertValid("ModelPreferences", {
    hints: [{name: "sonnet", vendorHint: true}],
    speedPriority: 1,
    vendorPreference: [true, "value"],
  })
})

test("sampling requires exact request, message, and parameter shapes", () => {
  const params = officialFixtures.CreateMessageRequestParams[0]
  for (const fixture of [
    {},
    {method: "roots/list", params},
    {method: "sampling/createMessage"},
    {method: "sampling/createMessage", params: {}},
  ]) {
    assertInvalid("CreateMessageRequest", fixture)
  }

  for (const fixture of [
    {...params, messages: {}},
    {...params, maxTokens: 1.5},
    {...params, modelPreferences: {speedPriority: 1.1}},
    {...params, includeContext: "connectedServers"},
    {...params, stopSequences: [1]},
    {...params, metadata: []},
    {...params, tools: [{}]},
    {...params, toolChoice: {mode: "any"}},
  ]) {
    assertInvalid("CreateMessageRequestParams", fixture)
  }

  for (const fixture of [
    {content: {type: "text", text: "missing role"}},
    {role: "system", content: {type: "text", text: "invalid role"}},
    {role: "user"},
    {role: "user", content: {type: "resource_link", name: "x", uri: "file:///x"}},
  ]) {
    assertInvalid("SamplingMessage", fixture)
  }
})

test("sampling enforces role-sensitive tool use and result sequencing", () => {
  const toolUse = {type: "tool_use", id: "call-1", name: "weather", input: {city: "Paris"}}
  const toolResult = {
    type: "tool_result",
    toolUseId: "call-1",
    content: [{type: "text", text: "Sunny"}],
  }
  const text = {type: "text", text: "text"}
  const base = {maxTokens: 100}
  const invalidFixtures = [
    {...base, messages: [{role: "user", content: toolUse}]},
    {...base, messages: [{role: "assistant", content: toolResult}]},
    {...base, messages: [{role: "assistant", content: toolUse}]},
    {
      ...base,
      messages: [
        {role: "assistant", content: toolUse},
        {role: "user", content: [toolResult, text]},
      ],
    },
    {
      ...base,
      messages: [
        {role: "assistant", content: toolUse},
        {role: "user", content: {...toolResult, toolUseId: "call-2"}},
      ],
    },
    {
      ...base,
      messages: [
        {role: "assistant", content: [toolUse, {...toolUse, id: "call-2"}]},
        {role: "user", content: toolResult},
      ],
    },
    {
      ...base,
      messages: [
        {role: "assistant", content: [toolUse, {...toolUse}]},
        {
          role: "user",
          content: [toolResult, {...toolResult, toolUseId: "call-2"}],
        },
      ],
    },
    {
      ...base,
      messages: [
        {role: "assistant", content: [toolUse, {...toolUse, id: "call-2"}]},
        {role: "user", content: [toolResult, {...toolResult}]},
      ],
    },
  ]

  for (const fixture of invalidFixtures) {
    assert.throws(() => S.parseOrThrow(fixture, CreateMessageRequestParams.schema))
    assert.equal(oracle.validate("CreateMessageRequestParams", fixture).valid, true)
    assert.equal(generatedValidators.CreateMessageRequestParams(fixture), true)
  }
})
