import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {
  HeaderMismatchError,
  InternalError,
  InvalidParamsError,
  InvalidRequestError,
  MethodNotFoundError,
  MissingRequiredClientCapabilityError,
  ModernErrorCode,
  ParseError,
  UnsupportedProtocolVersionError,
} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema} from "./GeneratedSchema.mjs"

const readJson = async url => JSON.parse(await readFile(url, "utf8"))
const upstreamSchema = await readJson(new URL("mcp-upstream/schema.json", import.meta.url))
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const wireValue = value => JSON.parse(JSON.stringify(value))

const contracts = [
  {
    definition: "ParseError",
    schema: ParseError.schema,
    generated: "parseError",
    fixture: "ParseError/invalid-json.json",
  },
  {
    definition: "InvalidRequestError",
    schema: InvalidRequestError.schema,
    generated: "invalidRequestError",
    value: {code: -32600, message: "Invalid request"},
  },
  {
    definition: "MethodNotFoundError",
    schema: MethodNotFoundError.schema,
    generated: "methodNotFoundError",
    fixture: "MethodNotFoundError/prompts-not-supported.json",
  },
  {
    definition: "InvalidParamsError",
    schema: InvalidParamsError.schema,
    generated: "invalidParamsError",
    fixture: "InvalidParamsError/invalid-tool-arguments.json",
  },
  {
    definition: "InternalError",
    schema: InternalError.schema,
    generated: "internalError",
    fixture: "InternalError/unexpected-error.json",
  },
  {
    definition: "HeaderMismatchError",
    schema: HeaderMismatchError.schema,
    generated: "headerMismatchError",
    fixture: "HeaderMismatchError/header-mismatch.json",
  },
  {
    definition: "MissingRequiredClientCapabilityError",
    schema: MissingRequiredClientCapabilityError.schema,
    generated: "missingRequiredClientCapabilityError",
    fixture: "MissingRequiredClientCapabilityError/missing-elicitation-capability.json",
  },
  {
    definition: "UnsupportedProtocolVersionError",
    schema: UnsupportedProtocolVersionError.schema,
    generated: "unsupportedProtocolVersionError",
    fixture: "UnsupportedProtocolVersionError/unsupported-version.json",
  },
]

for (const contract of contracts) {
  contract.value ??= await readJson(
    new URL(`mcp-upstream/examples/${contract.fixture}`, import.meta.url),
  )
  contract.generatedSchema = generatedSchema(`mcp/${contract.generated}`)
  contract.validateGenerated = ajv.compile(contract.generatedSchema)
}

const assertValid = (contract, value) => {
  const parsed = S.parseOrThrow(value, contract.schema)
  const encoded = wireValue(S.decodeOrThrow(parsed, contract.schema, S.json))

  assert.deepEqual(encoded, value)
  assert.equal(oracle.validate(contract.definition, encoded).valid, true)
  assert.equal(contract.validateGenerated(encoded), true)
}

const assertInvalid = (contract, value) => {
  assert.throws(() => S.parseOrThrow(value, contract.schema))
  assert.equal(oracle.validate(contract.definition, value).valid, false)
  assert.equal(contract.validateGenerated(value), false)
}

test("named errors accept and preserve their official wire values", () => {
  for (const contract of contracts) {
    assertValid(contract, contract.value)
  }
})

test("named errors preserve open envelope, error, and data fields", () => {
  for (const contract of contracts) {
    const value = structuredClone(contract.value)
    value.vendor = {preserved: true}

    switch ("error" in value) {
      case true:
        value.error.vendor = [null, true]
        if (value.error.data !== undefined) {
          value.error.data.vendor = "preserved"
        }
        break
      case false:
        value.vendorData = [null, true]
        break
    }

    assertValid(contract, value)
  }
})

test("named errors reject incorrect codes and missing required fields", () => {
  for (const contract of contracts) {
    const wrongCode = structuredClone(contract.value)
    const error = "error" in wrongCode ? wrongCode.error : wrongCode
    error.code -= 1
    assertInvalid(contract, wrongCode)

    switch ("error" in contract.value) {
      case true:
        for (const field of ["jsonrpc", "error"]) {
          const missingField = structuredClone(contract.value)
          delete missingField[field]
          assertInvalid(contract, missingField)
        }
        for (const field of ["code", "message"]) {
          const missingField = structuredClone(contract.value)
          delete missingField.error[field]
          assertInvalid(contract, missingField)
        }
        break
      case false:
        for (const field of ["code", "message"]) {
          const missingField = structuredClone(contract.value)
          delete missingField[field]
          assertInvalid(contract, missingField)
        }
        break
    }
  }
})

test("capability and version errors require their exact data shapes", () => {
  const capabilityContract = contracts.find(
    contract => contract.definition === "MissingRequiredClientCapabilityError",
  )
  const missingCapabilities = structuredClone(capabilityContract.value)
  delete missingCapabilities.error.data.requiredCapabilities
  assertInvalid(capabilityContract, missingCapabilities)

  const malformedCapabilities = structuredClone(capabilityContract.value)
  malformedCapabilities.error.data.requiredCapabilities = []
  assertInvalid(capabilityContract, malformedCapabilities)

  const openCapabilities = structuredClone(capabilityContract.value)
  openCapabilities.error.data.requiredCapabilities["ai.frontman/vendor"] = {
    nested: [null, true],
  }
  assertValid(capabilityContract, openCapabilities)

  const missingCapabilityData = structuredClone(capabilityContract.value)
  delete missingCapabilityData.error.data
  assertInvalid(capabilityContract, missingCapabilityData)

  const versionContract = contracts.find(
    contract => contract.definition === "UnsupportedProtocolVersionError",
  )
  const missingRequested = structuredClone(versionContract.value)
  delete missingRequested.error.data.requested
  assertInvalid(versionContract, missingRequested)

  const malformedVersion = structuredClone(versionContract.value)
  malformedVersion.error.data.supported = "2026-07-28"
  assertInvalid(versionContract, malformedVersion)

  const missingVersionData = structuredClone(versionContract.value)
  delete missingVersionData.error.data
  assertInvalid(versionContract, missingVersionData)
})

test("MCP-reserved named codes are exactly the defined initial inventory", () => {
  const codes = [...ModernErrorCode.mcpReserved].sort((left, right) => left - right)
  const contractCodes = contracts
    .map(contract => contract.value.error?.code ?? contract.value.code)
    .filter(code => code <= -32020 && code >= -32099)
    .sort((left, right) => left - right)

  assert.deepEqual(codes, [-32022, -32021, -32020])
  assert.deepEqual(contractCodes, codes)
  assert.equal(codes.includes(-32002), false)
  assert.equal(codes.includes(-32042), false)
})
