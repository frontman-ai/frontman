import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"
import * as S from "sury/src/S.res.mjs"
import {Implementation} from "../src/FrontmanProtocol__MCP.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"
import {generatedSchema as getGeneratedSchema} from "./GeneratedSchema.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const generatedSchema = getGeneratedSchema("mcp/implementation")
const oracle = createOracle(upstreamSchema)
const ajv = new Ajv2020({strict: true})
addFormats(ajv)
const validateGenerated = ajv.compile(generatedSchema)
const wireValue = value => JSON.parse(JSON.stringify(value))

const fixtures = [
  {name: "frontman", version: "1.0.0"},
  {
    name: "frontman",
    version: "1.0.0",
    title: "Frontman",
    description: "Browser development agent",
    websiteUrl: "https://frontman.sh",
    icons: [
      {src: "https://frontman.sh/icon.png", mimeType: "image/png", sizes: ["48x48"], theme: "dark"},
      {src: "data:image/png;base64,aWNvbg==", theme: "light"},
    ],
  },
]

test("implementation identities round-trip within the upstream definition", () => {
  for (const fixture of fixtures) {
    const parsed = S.parseOrThrow(fixture, Implementation.schema)
    const encoded = wireValue(S.decodeOrThrow(parsed, Implementation.schema, S.json))

    assert.deepEqual(encoded, fixture)
    assert.equal(oracle.validate("Implementation", encoded).valid, true)
    assert.equal(validateGenerated(encoded), true)
  }
})

test("implementation identities reject missing and malformed fields", () => {
  const invalid = [
    {version: "1.0.0"},
    {name: "frontman"},
    {name: 1, version: "1.0.0"},
    {name: "frontman", version: 1},
    {...fixtures[0], title: 1},
    {...fixtures[0], description: false},
    {...fixtures[0], websiteUrl: "not a URI"},
    {...fixtures[0], icons: [{src: "not a URI"}]},
    {...fixtures[0], icons: [{src: "https://frontman.sh/icon.png", theme: "sepia"}]},
  ]

  for (const fixture of invalid) {
    assert.throws(() => S.parseOrThrow(fixture, Implementation.schema))
    assert.equal(oracle.validate("Implementation", fixture).valid, false)
    assert.equal(validateGenerated(fixture), false)
  }
})
