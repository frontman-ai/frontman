import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import * as ContentBlock from "../src/FrontmanProtocol__ContentBlock.res.mjs"
import {Id} from "../src/FrontmanProtocol__JsonRpc.res.mjs"
import {
  CallToolRequestParams,
  CallToolResult,
  CancelledNotificationParams,
  RequestMeta,
  Tool,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import * as Metadata from "../src/FrontmanProtocol__MCPMetadata.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)

const generatedSchemas = {
  cancellation: generatedSchema("mcp/cancelledNotificationParams"),
  callParams: generatedSchema("mcp/callToolRequestParams"),
  content: generatedSchema("mcp/callToolResult"),
  id: generatedSchema("jsonrpc/request"),
  metadata: generatedSchema("mcp/metaObject"),
  requestMeta: generatedSchema("mcp/requestMeta"),
  tool: generatedSchema("mcp/tool"),
}
const generated = Object.fromEntries(
  Object.entries(generatedSchemas).map(([name, schema]) => [name, ajv.compile(schema)]),
)

const parseBoundedInteger = (name, defaultValue, maximum) => {
  const input = process.env[name] ?? defaultValue
  assert.match(input, /^[1-9][0-9]*$/, `${name} must be a positive integer`)
  const value = Number(input)
  assert.ok(Number.isSafeInteger(value) && value <= maximum, `${name} must not exceed ${maximum}`)
  return value
}

const caseCount = parseBoundedInteger("MCP_PROPERTY_CASES", "1000", 100000)
const seed = parseBoundedInteger("MCP_PROPERTY_SEED", "20260728", 0xffffffff)
const createRandom = initialSeed => {
  let state = initialSeed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let value = state
    value = Math.imul(value ^ value >>> 15, value | 1)
    value ^= value + Math.imul(value ^ value >>> 7, value | 61)
    return ((value ^ value >>> 14) >>> 0) / 0x100000000
  }
}
const random = createRandom(seed)
const randomInteger = maximum => Math.floor(random() * maximum)
const randomBoolean = () => random() < 0.5
const randomString = maximumLength => {
  const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._- "
  return Array.from(
    {length: randomInteger(maximumLength + 1)},
    () => alphabet[randomInteger(alphabet.length)],
  ).join("")
}
const randomJson = depth => {
  const kind = randomInteger(depth >= 2 ? 4 : 6)
  switch (kind) {
    case 0:
      return null
    case 1:
      return randomBoolean()
    case 2:
      return randomInteger(2001) - 1000
    case 3:
      return randomString(24)
    case 4:
      return Array.from({length: randomInteger(5)}, () => randomJson(depth + 1))
    case 5:
      return Object.fromEntries(
        Array.from({length: randomInteger(5)}, (_, index) => [`value-${index}`, randomJson(depth + 1)]),
      )
  }
}
const randomSafeInteger = () => {
  const high = randomInteger(0x200000)
  const low = randomInteger(0x100000000)
  const magnitude = high * 0x100000000 + low
  return randomBoolean() ? magnitude : -magnitude
}
const randomId = iteration => {
  const boundaries = [0, -1, Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER]
  if (iteration < boundaries.length) {
    return boundaries[iteration]
  }
  return randomBoolean() ? randomString(64) : randomSafeInteger()
}
const wireValue = (parsed, schema) => JSON.parse(JSON.stringify(S.decodeOrThrow(parsed, schema, S.json)))
const assertAccepted = ({definition, generatedValidator, label, schema, value, generatedValue = value}) => {
  const encoded = wireValue(S.parseOrThrow(value, schema), schema)
  assert.deepEqual(encoded, value, `${label} did not round-trip at seed ${seed}`)
  const upstream = oracle.validate(definition, encoded)
  assert.equal(upstream.valid, true, `${label} escaped the upstream domain at seed ${seed}: ${JSON.stringify(upstream.errors)}`)
  assert.equal(generatedValidator(generatedValue), true, `${label} escaped the generated schema at seed ${seed}: ${JSON.stringify(generatedValidator.errors)}`)
}
const assertRejected = ({definition, generatedValidator, label, schema, value}) => {
  assert.throws(() => S.parseOrThrow(value, schema), undefined, `${label} passed locally at seed ${seed}`)
  assert.equal(oracle.validate(definition, value).valid, false, `${label} passed upstream at seed ${seed}`)
  assert.equal(generatedValidator(value), false, `${label} passed the generated schema at seed ${seed}`)
}

test(`deterministic local MCP values remain inside upstream domains (${caseCount} cases, seed ${seed})`, () => {
  for (let iteration = 0; iteration < caseCount; iteration += 1) {
    const id = randomId(iteration)
    const parsedId = S.parseOrThrow(id, Id.schema)
    assert.strictEqual(Id.toJson(parsedId), id)
    assert.equal(oracle.validate("RequestId", id).valid, true, `ID case ${iteration}`)
    assert.equal(generated.id({jsonrpc: "2.0", id, method: "property/test"}), true, `ID schema case ${iteration}`)

    const progressToken = randomId(iteration + 1)
    const requestMeta = {
      "io.modelcontextprotocol/protocolVersion": "2026-07-28",
      "io.modelcontextprotocol/clientCapabilities": {},
      progressToken,
      "example.com/property": randomJson(0),
    }
    assertAccepted({
      definition: "RequestMetaObject",
      generatedValidator: generated.requestMeta,
      label: `progress token case ${iteration}`,
      schema: RequestMeta.schema,
      value: requestMeta,
    })

    const cancellation = {
      requestId: randomId(iteration + 2),
      reason: randomString(48),
      _meta: {"example.com/property": randomJson(0)},
    }
    assertAccepted({
      definition: "CancelledNotificationParams",
      generatedValidator: generated.cancellation,
      label: `cancellation ID case ${iteration}`,
      schema: CancelledNotificationParams.schema,
      value: cancellation,
    })

    const theme = randomBoolean() ? "dark" : "light"
    const iconTool = {
      name: randomString(48),
      inputSchema: {type: "object"},
      icons: [{src: `https://example.com/icon-${iteration}.png`, theme}],
    }
    assertAccepted({
      definition: "Tool",
      generatedValidator: generated.tool,
      label: `icon theme case ${iteration}`,
      schema: Tool.schema,
      value: iconTool,
    })

    const audience = Array.from(
      {length: randomInteger(7)},
      () => randomBoolean() ? "assistant" : "user",
    )
    const audienceContent = {type: "text", text: randomString(64), annotations: {audience}}
    assertAccepted({
      definition: "TextContent",
      generatedValidator: value => generated.content({resultType: "complete", content: [value]}),
      label: `audience case ${iteration}`,
      schema: ContentBlock.schema,
      value: audienceContent,
    })

    const sizeBoundaries = [0, -1, Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, -1e100, 1e100]
    const size = iteration < sizeBoundaries.length ? sizeBoundaries[iteration] : randomSafeInteger()
    const resource = {
      type: "resource_link",
      name: randomString(48),
      uri: `file:///tmp/property-${iteration}`,
      size,
    }
    assertAccepted({
      definition: "ResourceLink",
      generatedValidator: value => generated.content({resultType: "complete", content: [value]}),
      label: `resource size case ${iteration}`,
      schema: ContentBlock.schema,
      value: resource,
    })

    const inputSchema = {
      type: "object",
      title: randomString(32),
      properties: {value: randomJson(0)},
      "x-property-case": randomJson(0),
    }
    const schemaTool = {name: `property-${iteration}`, inputSchema}
    assertAccepted({
      definition: "Tool",
      generatedValidator: generated.tool,
      label: `tool input schema case ${iteration}`,
      schema: Tool.schema,
      value: schemaTool,
    })

    const callParams = {
      _meta: {
        "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": {},
      },
      name: randomString(48),
      arguments: Object.fromEntries(
        Array.from({length: randomInteger(6)}, (_, index) => [`argument-${index}`, randomJson(0)]),
      ),
    }
    assertAccepted({
      definition: "CallToolRequestParams",
      generatedValidator: generated.callParams,
      label: `tool arguments case ${iteration}`,
      schema: CallToolRequestParams.schema,
      value: callParams,
    })

    const result = {
      resultType: "complete",
      content: [],
      structuredContent: randomJson(0),
    }
    assertAccepted({
      definition: "CallToolResult",
      generatedValidator: generated.content,
      label: `structured content case ${iteration}`,
      schema: CallToolResult.schema,
      value: result,
    })

    const keyCount = iteration === 0 ? 64 : randomInteger(65)
    const metadata = Object.fromEntries(
      Array.from({length: keyCount}, (_, index) => [`example.com/property-${index}`, randomJson(1)]),
    )
    assertAccepted({
      definition: "MetaObject",
      generatedValidator: generated.metadata,
      label: `metadata key boundary case ${iteration}`,
      schema: Metadata.schema,
      value: metadata,
    })

    const emptyPadding = {"example.com/padding": ""}
    const prefixBytes = Buffer.byteLength(JSON.stringify(emptyPadding))
    const paddingLength = iteration === 0
      ? Metadata.maxBytes - prefixBytes
      : randomInteger(Metadata.maxBytes - prefixBytes + 1)
    const byteMetadata = {"example.com/padding": "x".repeat(paddingLength)}
    assertAccepted({
      definition: "MetaObject",
      generatedValidator: generated.metadata,
      label: `metadata byte boundary case ${iteration}`,
      schema: Metadata.schema,
      value: byteMetadata,
    })

    const requiredMutations = [
      {
        definition: "RequestMetaObject",
        generatedValidator: generated.requestMeta,
        schema: RequestMeta.schema,
        value: requestMeta,
        field: randomBoolean()
          ? "io.modelcontextprotocol/protocolVersion"
          : "io.modelcontextprotocol/clientCapabilities",
      },
      {
        definition: "CancelledNotificationParams",
        generatedValidator: generated.cancellation,
        schema: CancelledNotificationParams.schema,
        value: cancellation,
        field: "requestId",
      },
      {
        definition: "Tool",
        generatedValidator: generated.tool,
        schema: Tool.schema,
        value: schemaTool,
        field: randomBoolean() ? "name" : "inputSchema",
      },
      {
        definition: "CallToolRequestParams",
        generatedValidator: generated.callParams,
        schema: CallToolRequestParams.schema,
        value: callParams,
        field: randomBoolean() ? "_meta" : "name",
      },
      {
        definition: "CallToolResult",
        generatedValidator: generated.content,
        schema: CallToolResult.schema,
        value: result,
        field: randomBoolean() ? "resultType" : "content",
      },
    ]
    const mutation = requiredMutations[iteration % requiredMutations.length]
    const {[mutation.field]: _removed, ...withoutRequiredField} = mutation.value
    assertRejected({
      definition: mutation.definition,
      generatedValidator: mutation.generatedValidator,
      label: `required field case ${iteration}`,
      schema: mutation.schema,
      value: withoutRequiredField,
    })
  }
})
