import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  CancelledNotification,
  CancelledNotificationParams,
  NotificationMeta,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import * as Metadata from "../src/FrontmanProtocol__MCPMetadata.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const officialFixtures = {
  CancelledNotification: await readJson(
    new URL(
      "mcp-upstream/examples/CancelledNotification/user-requested-cancellation.json",
      import.meta.url,
    ),
  ),
  CancelledNotificationParams: await readJson(
    new URL(
      "mcp-upstream/examples/CancelledNotificationParams/user-requested-cancellation.json",
      import.meta.url,
    ),
  ),
}
const generatedSchemas = {
  CancelledNotification: generatedSchema("mcp/cancelledNotification"),
  CancelledNotificationParams: generatedSchema("mcp/cancelledNotificationParams"),
  NotificationMeta: generatedSchema("mcp/notificationMeta"),
}
const schemas = {
  CancelledNotification: CancelledNotification.schema,
  CancelledNotificationParams: CancelledNotificationParams.schema,
  NotificationMeta: NotificationMeta.schema,
}
const oracleNames = {NotificationMeta: "NotificationMetaObject"}
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
  assert.equal(oracle.validate(oracleNames[name] ?? name, encoded).valid, true)
  assert.equal(generatedValidators[name](encoded), true)
}

const assertInvalid = (name, fixture) => {
  assert.throws(() => S.parseOrThrow(fixture, schemas[name]))
  assert.equal(oracle.validate(oracleNames[name] ?? name, fixture).valid, false)
  assert.equal(generatedValidators[name](fixture), false)
}

test("official cancellation fixtures round-trip and validate upstream", () => {
  assertValid("CancelledNotification", officialFixtures.CancelledNotification)
  assertValid("CancelledNotificationParams", officialFixtures.CancelledNotificationParams)
})

test("cancellation preserves the complete request ID domain and open fields", () => {
  for (const requestId of ["", "request-1", 0, -1, 2147483648, Number.MAX_SAFE_INTEGER]) {
    assertValid("CancelledNotification", {
      jsonrpc: "2.0",
      method: "notifications/cancelled",
      params: {
        requestId,
        reason: "cancel",
        vendorParam: {preserved: true},
      },
      vendorEnvelope: [true, "preserved"],
    })
  }
})

test("cancellation metadata preserves valid subscription IDs and vendor values", () => {
  assertValid("NotificationMeta", {})
  assertValid("NotificationMeta", {
    "io.modelcontextprotocol/subscriptionId": "subscription-1",
    "example.com/cancellation": {nested: [true, 1, "value"]},
  })
  assertValid("CancelledNotificationParams", {
    requestId: "request-1",
    _meta: {
      "io.modelcontextprotocol/subscriptionId": Number.MAX_SAFE_INTEGER,
      "example.com/reason": "timeout",
    },
  })
})

test("cancellation metadata enforces the procedural compact UTF-8 byte limit", () => {
  const prefix = Buffer.byteLength(JSON.stringify({"example.com/cancellation": ""}))
  const atLimit = {"example.com/cancellation": "x".repeat(Metadata.maxBytes - prefix)}
  const overLimit = {"example.com/cancellation": "x".repeat(Metadata.maxBytes - prefix + 1)}

  assertValid("NotificationMeta", atLimit)
  assert.throws(() => S.parseOrThrow(overLimit, NotificationMeta.schema))
  assert.throws(() =>
    S.parseOrThrow(
      {requestId: "request-1", _meta: overLimit},
      CancelledNotificationParams.schema,
    )
  )
  assert.equal(generatedValidators.NotificationMeta(overLimit), true)
  assert.equal(
    generatedValidators.CancelledNotificationParams({requestId: "request-1", _meta: overLimit}),
    true,
  )
  assert.equal(oracle.validate("NotificationMetaObject", overLimit).valid, true)
})

test("cancellation requires exact envelope, parameter, ID, and metadata shapes", () => {
  for (const fixture of [
    {},
    {jsonrpc: "1.0", method: "notifications/cancelled", params: {requestId: "1"}},
    {jsonrpc: "2.0", method: "notifications/cancel", params: {requestId: "1"}},
    {jsonrpc: "2.0", method: "notifications/cancelled"},
    {jsonrpc: "2.0", method: "notifications/cancelled", params: {}},
    {jsonrpc: "2.0", method: "notifications/cancelled", params: {requestId: null}},
    {jsonrpc: "2.0", method: "notifications/cancelled", params: {requestId: 1.5}},
    {jsonrpc: "2.0", method: "notifications/cancelled", params: {requestId: true}},
    {
      jsonrpc: "2.0",
      method: "notifications/cancelled",
      params: {requestId: "1", reason: 1},
    },
    {
      jsonrpc: "2.0",
      method: "notifications/cancelled",
      params: {requestId: "1", _meta: []},
    },
  ]) {
    assertInvalid("CancelledNotification", fixture)
  }

  for (const fixture of [
    {"io.modelcontextprotocol/subscriptionId": null},
    {"io.modelcontextprotocol/subscriptionId": 1.5},
    {"io.modelcontextprotocol/subscriptionId": true},
  ]) {
    assertInvalid("NotificationMeta", fixture)
  }

  const invalidMetadataKey = {"invalid key!": true}
  assert.throws(() => S.parseOrThrow(invalidMetadataKey, NotificationMeta.schema))
  assert.equal(generatedValidators.NotificationMeta(invalidMetadataKey), false)
  assert.equal(oracle.validate("NotificationMetaObject", invalidMetadataKey).valid, true)
})

test("runtime and generated schemas reject IDs on cancellation notifications", () => {
  const fixture = {...officialFixtures.CancelledNotification, id: "not-a-notification"}

  assert.throws(() => S.parseOrThrow(fixture, CancelledNotification.schema))
  assert.equal(generatedValidators.CancelledNotification(fixture), false)
  assert.equal(oracle.validate("CancelledNotification", fixture).valid, true)
})
