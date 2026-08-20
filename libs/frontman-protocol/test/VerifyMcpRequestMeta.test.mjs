import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {RequestMeta} from "../src/FrontmanProtocol__MCP.res.mjs"
import * as Metadata from "../src/FrontmanProtocol__MCPMetadata.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = getGeneratedSchema("mcp/requestMeta")
const generatedMetadataSchema = getGeneratedSchema("mcp/metaObject")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const validateGeneratedMetadata = ajv.compile(generatedMetadataSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const minimal = {
  "io.modelcontextprotocol/protocolVersion": "2026-07-28",
  "io.modelcontextprotocol/clientCapabilities": {},
}

const full = {
  ...minimal,
  "io.modelcontextprotocol/clientInfo": {name: "frontman", version: "1.0.0"},
  "io.modelcontextprotocol/logLevel": "warning",
  progressToken: "progress-1",
  "ai.frontman/execution-context": {taskId: "task-1", toolCallId: "call-1"},
  "com.example/value": [null, 1.5, true],
}

test("request metadata preserves required, optional, and vendor fields", () => {
  for (const fixture of [minimal, full, {...minimal, progressToken: Number.MAX_SAFE_INTEGER}]) {
    const parsed = S.parseOrThrow(fixture, RequestMeta.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, RequestMeta.schema, S.json))

    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("RequestMetaObject", encoded).valid, true)
    assert.equal(validateGenerated(encoded), true)
  }
})

test("request metadata accepts every logging level and progress-token boundary", () => {
  const levels = ["alert", "critical", "debug", "emergency", "error", "info", "notice", "warning"]
  const tokens = ["", "progress-1", 0, -1, Number.MAX_SAFE_INTEGER]

  for (const logLevel of levels) {
    assert.doesNotThrow(() =>
      S.parseOrThrow({...minimal, "io.modelcontextprotocol/logLevel": logLevel}, RequestMeta.schema)
    )
  }
  for (const progressToken of tokens) {
    const fixture = {...minimal, progressToken}
    assert.doesNotThrow(() => S.parseOrThrow(fixture, RequestMeta.schema))
    assert.equal(oracle.validate("RequestMetaObject", fixture).valid, true)
  }
})

test("request metadata requires version and per-request capabilities", () => {
  const {"io.modelcontextprotocol/protocolVersion": _version, ...withoutVersion} = minimal
  const {"io.modelcontextprotocol/clientCapabilities": _capabilities, ...withoutCapabilities} = minimal

  for (const fixture of [withoutVersion, withoutCapabilities]) {
    assert.throws(() => S.parseOrThrow(fixture, RequestMeta.schema))
    assert.equal(oracle.validate("RequestMetaObject", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})

test("request metadata rejects malformed reserved fields", () => {
  const invalid = [
    {...minimal, "io.modelcontextprotocol/protocolVersion": 20260728},
    {...minimal, "io.modelcontextprotocol/clientCapabilities": []},
    {...minimal, "io.modelcontextprotocol/clientInfo": {name: "frontman"}},
    {...minimal, "io.modelcontextprotocol/logLevel": "verbose"},
    {...minimal, progressToken: null},
    {...minimal, progressToken: true},
    {...minimal, progressToken: 1.5},
    {...minimal, progressToken: {}},
    {...minimal, progressToken: []},
  ]

  for (const fixture of invalid) {
    assert.throws(() => S.parseOrThrow(fixture, RequestMeta.schema))
    assert.equal(oracle.validate("RequestMetaObject", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})

test("generic metadata rejects trace propagation fields and preserves vendor fields", () => {
  const vendorMetadata = {"com.example/value": [null, 1.5, true]}
  const parsed = S.parseOrThrow(vendorMetadata, Metadata.schema)

  assert.deepEqual(wireValue(S.decodeOrThrow(parsed, Metadata.schema, S.json)), vendorMetadata)
  assert.equal(validateGeneratedMetadata(vendorMetadata), true)

  for (const field of ["traceparent", "tracestate", "baggage"]) {
    const metadata = {...vendorMetadata, [field]: "must-not-propagate"}
    const requestMetadata = {...minimal, ...metadata}

    assert.throws(() => S.parseOrThrow(metadata, Metadata.schema))
    assert.throws(() => S.parseOrThrow(requestMetadata, RequestMeta.schema))
    assert.equal(validateGeneratedMetadata(metadata), false)
    assert.equal(validateGenerated(requestMetadata), false)
  }
})

test("request metadata applies key and byte limits including required fields", () => {
  const atKeyLimit = {...minimal}
  for (let index = 0; index < 62; index += 1) {
    atKeyLimit[`com.example/key-${index}`] = index
  }

  assert.deepEqual(S.parseOrThrow(atKeyLimit, RequestMeta.schema), atKeyLimit)
  assert.throws(() => S.parseOrThrow({...atKeyLimit, "com.example/key-62": 62}, RequestMeta.schema))

  const withEmptyPadding = {...minimal, "com.example/padding": ""}
  const prefixBytes = Buffer.byteLength(JSON.stringify(withEmptyPadding))
  const atByteLimit = {
    ...minimal,
    "com.example/padding": "x".repeat(Metadata.maxBytes - prefixBytes),
  }

  assert.equal(Buffer.byteLength(JSON.stringify(atByteLimit)), Metadata.maxBytes)
  assert.deepEqual(S.parseOrThrow(atByteLimit, RequestMeta.schema), atByteLimit)
  assert.throws(() =>
    S.parseOrThrow(
      {...atByteLimit, "com.example/padding": `${atByteLimit["com.example/padding"]}x`},
      RequestMeta.schema,
    )
  )
})
