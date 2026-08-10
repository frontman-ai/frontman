import {readFile} from "node:fs/promises"
import {dirname, join, resolve} from "node:path"
import {fileURLToPath} from "node:url"

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const traceabilityRoot = resolve(packageRoot, "../../docs/mcp/traceability")
const expectedCounts = new Map([
  ["base-versioning.md", 74],
  ["http-security.md", 125],
  ["tools-discovery.md", 106],
  ["patterns-optional.md", 138],
])
const expectedHeader = [
  "Requirement ID",
  "Normative text",
  "Applicability",
  "Code location",
  "Positive test",
  "Negative test",
  "Status",
  "Notes",
]

const cells = line => line.split("|").slice(1, -1).map(value => value.trim())

export const parseMatrix = (source, name) => {
  const ids = []
  let insideMatrix = false
  for (const line of source.split("\n")) {
    if (!line.startsWith("|")) {
      insideMatrix = false
      continue
    }
    const values = cells(line)
    if (values.length !== expectedHeader.length) {
      throw new Error(`${name} contains a table row with ${values.length} columns`)
    }
    if (JSON.stringify(values) === JSON.stringify(expectedHeader)) {
      insideMatrix = true
      continue
    }
    if (values.every(value => /^-+$/.test(value))) {
      if (!insideMatrix) {
        throw new Error(`${name} contains a separator without the required header`)
      }
      continue
    }
    if (!insideMatrix) {
      continue
    }
    if (values.some(value => value === "")) {
      throw new Error(`${name} contains an empty traceability cell`)
    }
    const linkedId = values[0].match(/^\[([^\]]+)\]/)
    ids.push(linkedId === null ? values[0] : linkedId[1])
  }
  return ids
}

export const verifyTraceability = async (root, counts = expectedCounts) => {
  const allIds = []
  for (const [name, expectedCount] of counts) {
    const ids = parseMatrix(await readFile(join(root, name), "utf8"), name)
    if (ids.length !== expectedCount) {
      throw new Error(`${name} has ${ids.length} requirements; expected ${expectedCount}`)
    }
    allIds.push(...ids)
  }
  if (new Set(allIds).size !== allIds.length) {
    const duplicates = [...new Set(allIds.filter((id, index) => allIds.indexOf(id) !== index))]
    throw new Error(`Traceability matrices contain duplicate requirement IDs: ${duplicates.join(", ")}`)
  }
  return allIds.length
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const count = await verifyTraceability(traceabilityRoot)
  process.stdout.write(`Verified ${count} MCP normative traceability requirements.\n`)
}
