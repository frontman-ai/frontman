import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {CallToolResult, ResultMeta} from "../src/FrontmanProtocol__MCP.res.mjs"
import * as Metadata from "../src/FrontmanProtocol__MCPMetadata.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = getGeneratedSchema("mcp/resultMeta")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const full = {
  "io.modelcontextprotocol/serverInfo": {
    name: "frontman",
    version: "1.0.0",
    websiteUrl: "https://frontman.sh",
  },
  "ai.frontman/result": {source: "browser"},
  "com.example/value": [null, 1.5, true],
}

test("result metadata preserves empty, server, and vendor fields", () => {
  for (const fixture of [{}, full]) {
    const parsed = S.parseOrThrow(fixture, ResultMeta.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, ResultMeta.schema, S.json))

    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("ResultMetaObject", encoded).valid, true)
    assert.equal(validateGenerated(encoded), true)
  }
})

test("result metadata rejects malformed server identity", () => {
  const invalid = [
    {"io.modelcontextprotocol/serverInfo": null},
    {"io.modelcontextprotocol/serverInfo": "frontman"},
    {"io.modelcontextprotocol/serverInfo": {name: "frontman"}},
    {"io.modelcontextprotocol/serverInfo": {name: 1, version: "1.0.0"}},
  ]

  for (const fixture of invalid) {
    assert.throws(() => S.parseOrThrow(fixture, ResultMeta.schema))
    assert.equal(oracle.validate("ResultMetaObject", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})

test("complete tool results use result metadata", () => {
  const valid = {content: [], resultType: "complete", _meta: full}
  const invalid = {
    content: [],
    resultType: "complete",
    _meta: {"io.modelcontextprotocol/serverInfo": {name: "frontman"}},
  }

  assert.doesNotThrow(() => S.parseOrThrow(valid, CallToolResult.schema))
  assert.throws(() => S.parseOrThrow(invalid, CallToolResult.schema))
})

test("result metadata applies key and byte limits", () => {
  const atKeyLimit = {}
  for (let index = 0; index < Metadata.maxKeys; index += 1) {
    atKeyLimit[`com.example/key-${index}`] = index
  }

  assert.deepEqual(S.parseOrThrow(atKeyLimit, ResultMeta.schema), atKeyLimit)
  assert.throws(() => S.parseOrThrow({...atKeyLimit, "com.example/key-64": 64}, ResultMeta.schema))

  const prefixBytes = Buffer.byteLength(JSON.stringify({"com.example/padding": ""}))
  const atByteLimit = {"com.example/padding": "x".repeat(Metadata.maxBytes - prefixBytes)}

  assert.equal(Buffer.byteLength(JSON.stringify(atByteLimit)), Metadata.maxBytes)
  assert.deepEqual(S.parseOrThrow(atByteLimit, ResultMeta.schema), atByteLimit)
  assert.throws(() =>
    S.parseOrThrow(
      {...atByteLimit, "com.example/padding": `${atByteLimit["com.example/padding"]}x`},
      ResultMeta.schema,
    )
  )
})
