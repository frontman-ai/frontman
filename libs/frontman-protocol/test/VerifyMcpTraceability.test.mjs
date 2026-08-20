import assert from "node:assert/strict"
import {mkdir, mkdtemp, writeFile} from "node:fs/promises"
import {tmpdir} from "node:os"
import {join} from "node:path"
import test from "node:test"
import {parseMatrix, verifyTraceability} from "../scripts/VerifyMcpTraceability.mjs"

const header = "| Requirement ID | Normative text | Applicability | Code location | Positive test | Negative test | Status | Notes |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n"

test("traceability parser requires eight columns", () => {
  assert.throws(
    () => parseMatrix(`${header}| REQ-1 | text | applicable | code | positive | negative | status |\n`, "matrix.md"),
    /matrix.md contains a table row with 7 columns/,
  )
})

test("traceability verification rejects duplicate IDs", async () => {
  const root = await mkdtemp(join(tmpdir(), "frontman-mcp-traceability-"))
  await mkdir(root, {recursive: true})
  const row = "| REQ-1 | text | applicable | code | positive | negative | planned | notes |\n"
  await writeFile(join(root, "one.md"), header + row)
  await writeFile(join(root, "two.md"), header + row)
  await assert.rejects(
    verifyTraceability(root, new Map([["one.md", 1], ["two.md", 1]])),
    /Traceability matrices contain duplicate requirement IDs: REQ-1/,
  )
})

for (const placeholder of [
  "ABSENCE-JS",
  "ABSENCE-WP",
  "ABSENCE-PHX",
  "ABSENCE-CONFORMANCE",
  "No production OAuth owner; scoped source review",
]) {
  test(`traceability verification rejects deprecated evidence placeholder ${placeholder}`, async () => {
    const root = await mkdtemp(join(tmpdir(), "frontman-mcp-traceability-"))
    const row = `| REQ-1 | text | applicable | scoped ${placeholder} evidence | positive | negative | planned | notes |\n`
    await writeFile(join(root, "matrix.md"), header + row)
    await assert.rejects(
      verifyTraceability(root, new Map([["matrix.md", 1]])),
      new RegExp(`matrix.md requirement REQ-1 uses deprecated evidence placeholder: ${placeholder}`),
    )
  })
}
