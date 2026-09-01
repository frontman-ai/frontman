import assert from "node:assert/strict"
import {mkdtemp, readFile, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import {join} from "node:path"
import test from "node:test"
import {createOracle, sha256, verifyChecksums} from "../scripts/VerifyMcpOracle.mjs"

test("checksum verification rejects changed artifacts", async () => {
  const root = await mkdtemp(join(tmpdir(), "frontman-mcp-oracle-"))
  await writeFile(join(root, "artifact.json"), "changed")
  await writeFile(join(root, "SHA256SUMS"), `${sha256("original")}  artifact.json\n`)
  await assert.rejects(verifyChecksums(root), /Checksum mismatch: artifact.json/)
})

test("checksum verification rejects omitted artifacts", async () => {
  const root = await mkdtemp(join(tmpdir(), "frontman-mcp-oracle-"))
  await writeFile(join(root, "listed.json"), "listed")
  await writeFile(join(root, "omitted.json"), "omitted")
  await writeFile(join(root, "SHA256SUMS"), `${sha256("listed")}  listed.json\n`)
  await assert.rejects(verifyChecksums(root), /Checksum manifest does not match oracle artifacts/)
})

test("checksum verification rejects duplicate paths", async () => {
  const root = await mkdtemp(join(tmpdir(), "frontman-mcp-oracle-"))
  const entry = `${sha256("artifact")}  artifact.json\n`
  await writeFile(join(root, "artifact.json"), "artifact")
  await writeFile(join(root, "SHA256SUMS"), entry + entry)
  await assert.rejects(verifyChecksums(root), /Checksum manifest contains duplicate paths/)
})

test("the upstream CallToolRequest definition rejects missing params", async () => {
  const schemaPath = join(import.meta.dirname, "mcp-upstream/schema.json")
  const schema = JSON.parse(await readFile(schemaPath, "utf8"))
  const oracle = createOracle(schema)
  const valid = {
    jsonrpc: "2.0",
    id: "request-1",
    method: "tools/call",
    params: {
      name: "example",
      _meta: {
        "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": {},
      },
    },
  }
  assert.equal(oracle.validate("CallToolRequest", valid).valid, true)
  assert.equal(oracle.validate("CallToolRequest", {...valid, params: undefined}).valid, false)
})
