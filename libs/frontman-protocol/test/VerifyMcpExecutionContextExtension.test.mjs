import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  ExecutionContextExtension,
  InvalidParamsError,
  MissingRequiredClientCapabilityError,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {Wire} from "../src/FrontmanProtocol__JsonRpc.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const generated = {}

for (const name of [
  "executionContextExtensionSettings",
  "executionContext",
  "executionContextClientCapabilities",
  "executionContextServerCapabilities",
  "executionContextRequestMeta",
]) {
  generated[name] = ajv.compile(generatedSchema(`mcp/${name}`))
}

const identifier = "ai.frontman/execution-context"
const settings = {version: 1, vendorSetting: {preserved: true}}
const extensions = {
  [identifier]: settings,
  "com.example/other": {enabled: true},
}
const clientCapabilities = {
  extensions,
  vendorCapability: {nested: [null, true]},
}
const serverCapabilities = {
  extensions,
  tools: {},
  vendorCapability: {nested: [null, true]},
}
const requestMeta = {
  "io.modelcontextprotocol/protocolVersion": "2026-07-28",
  "io.modelcontextprotocol/clientCapabilities": clientCapabilities,
  [identifier]: {
    taskId: "task-1",
    toolCallId: "tool-call-1",
    vendorContext: {preserved: true},
  },
  "com.example/request": {preserved: true},
}
const wireValue = value => JSON.parse(JSON.stringify(value))

const roundTrip = (value, schema) => {
  const parsed = S.parseOrThrow(value, schema)
  return wireValue(S.decodeOrThrow(parsed, schema, S.json))
}

const assertInvalid = (value, schema, validateGenerated) => {
  assert.throws(() => S.parseOrThrow(value, schema))
  assert.equal(validateGenerated(value), false)
}

test("execution-context identifier and versioned settings are exact and lossless", () => {
  assert.equal(ExecutionContextExtension.identifier, identifier)
  assert.deepEqual(roundTrip(settings, ExecutionContextExtension.settingsSchema), settings)
  assert.equal(generated.executionContextExtensionSettings(settings), true)

  for (const value of [{}, {version: 2}, {version: "1"}, {version: 1.5}, null, []]) {
    assertInvalid(
      value,
      ExecutionContextExtension.settingsSchema,
      generated.executionContextExtensionSettings,
    )
  }
})

test("both peers advertise the execution-context extension explicitly", () => {
  const encodedClient = roundTrip(
    clientCapabilities,
    ExecutionContextExtension.clientCapabilitiesSchema,
  )
  const encodedServer = roundTrip(
    serverCapabilities,
    ExecutionContextExtension.serverCapabilitiesSchema,
  )

  assert.deepEqual(encodedClient, clientCapabilities)
  assert.deepEqual(encodedServer, serverCapabilities)
  assert.equal(oracle.validate("ClientCapabilities", encodedClient).valid, true)
  assert.equal(oracle.validate("ServerCapabilities", encodedServer).valid, true)
  assert.equal(generated.executionContextClientCapabilities(encodedClient), true)
  assert.equal(generated.executionContextServerCapabilities(encodedServer), true)
})

test("negotiation rejects absent and incompatible advertisements", () => {
  for (const value of [
    {},
    {extensions: {}},
    {extensions: {[identifier]: {}}},
    {extensions: {[identifier]: {version: 2}}},
    {extensions: {[identifier]: {version: "1"}}},
  ]) {
    assertInvalid(
      value,
      ExecutionContextExtension.clientCapabilitiesSchema,
      generated.executionContextClientCapabilities,
    )
    assertInvalid(
      value,
      ExecutionContextExtension.serverCapabilitiesSchema,
      generated.executionContextServerCapabilities,
    )
  }
})

test("request context parsing remains separate from client capability negotiation", () => {
  for (const capabilities of [
    {},
    {extensions: {}},
    {extensions: {[identifier]: {version: 2}}},
  ]) {
    const value = {
      ...requestMeta,
      "io.modelcontextprotocol/clientCapabilities": capabilities,
    }

    assert.deepEqual(roundTrip(value, ExecutionContextExtension.requestMetaSchema), value)
    assert.equal(generated.executionContextRequestMeta(value), true)
    assertInvalid(
      capabilities,
      ExecutionContextExtension.clientCapabilitiesSchema,
      generated.executionContextClientCapabilities,
    )
  }
})

test("custom transport request metadata carries explicit durable execution context", () => {
  const encoded = roundTrip(requestMeta, ExecutionContextExtension.requestMetaSchema)

  assert.deepEqual(encoded, requestMeta)
  assert.equal(oracle.validate("RequestMetaObject", encoded).valid, true)
  assert.equal(generated.executionContextRequestMeta(encoded), true)
})

test("custom transport request metadata rejects absent or malformed context", () => {
  const invalid = []
  const missingContext = structuredClone(requestMeta)
  delete missingContext[identifier]
  invalid.push(missingContext)

  for (const context of [
    {},
    {taskId: "task-1"},
    {toolCallId: "tool-call-1"},
    {taskId: "", toolCallId: "tool-call-1"},
    {taskId: "task-1", toolCallId: ""},
    {taskId: 1, toolCallId: "tool-call-1"},
    {taskId: "task-1", toolCallId: null},
    null,
    [],
  ]) {
    invalid.push({...requestMeta, [identifier]: context})
  }

  for (const value of invalid) {
    assert.equal(oracle.validate("RequestMetaObject", value).valid, true)
    assertInvalid(
      value,
      ExecutionContextExtension.requestMetaSchema,
      generated.executionContextRequestMeta,
    )
  }
})

test("missing negotiation uses the standard required-capability error contract", () => {
  const error = {
    jsonrpc: "2.0",
    id: "request-1",
    error: {
      code: -32021,
      message: "Client must support ai.frontman/execution-context version 1",
      data: {
        requiredCapabilities: {
          extensions: {[identifier]: {version: 1}},
        },
      },
    },
  }

  assert.deepEqual(
    roundTrip(error, MissingRequiredClientCapabilityError.schema),
    error,
  )
  assert.equal(oracle.validate("MissingRequiredClientCapabilityError", error).valid, true)
  assert.deepEqual(
    roundTrip(
      error.error.data.requiredCapabilities,
      ExecutionContextExtension.clientCapabilitiesSchema,
    ),
    error.error.data.requiredCapabilities,
  )
})

test("missing server negotiation has an exact local non-protocol failure", () => {
  assert.deepEqual(ExecutionContextExtension.missingServerSupport, {
    reason: "missing_required_server_extension",
    extension: identifier,
    requiredVersion: 1,
  })
})

test("malformed execution context uses a correlated invalid-params response", () => {
  const response = {
    jsonrpc: "2.0",
    id: "request-1",
    error: {
      code: -32602,
      message: "Invalid ai.frontman/execution-context metadata",
    },
  }

  assert.deepEqual(roundTrip(response, Wire.errorResponseSchema), response)
  assert.deepEqual(roundTrip(response.error, InvalidParamsError.schema), response.error)
  assert.equal(oracle.validate("JSONRPCErrorResponse", response).valid, true)
  assert.equal(oracle.validate("InvalidParamsError", response.error).valid, true)
})
