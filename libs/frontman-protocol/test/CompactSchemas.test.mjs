import assert from "node:assert/strict"
import {execFile} from "node:child_process"
import {mkdtemp, readdir, readFile, rm} from "node:fs/promises"
import {tmpdir} from "node:os"
import {dirname, join} from "node:path"
import test from "node:test"
import {promisify} from "node:util"
import {fileURLToPath, pathToFileURL} from "node:url"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"

const execFileAsync = promisify(execFile)
const packageDirectory = join(dirname(fileURLToPath(import.meta.url)), "..")

const generatedTree = async root => {
  assert.deepEqual(
    (await readdir(root)).toSorted(),
    ["acp", "generated.json", "jsonrpc", "mcp"],
  )
  const files = {}
  const visit = async (directory, relativeDirectory) => {
    for (const entry of await readdir(directory, {withFileTypes: true})) {
      if (relativeDirectory === "acp" && entry.name === "upstream") continue
      const relativePath = join(relativeDirectory, entry.name)
      const path = join(directory, entry.name)
      if (entry.isDirectory()) {
        await visit(path, relativePath)
      } else {
        files[relativePath] = await readFile(path, "utf8")
      }
    }
  }
  files["generated.json"] = await readFile(join(root, "generated.json"), "utf8")
  for (const directory of ["acp", "mcp", "jsonrpc"]) {
    await visit(join(root, directory), directory)
  }
  return files
}

const pointerValue = (document, ref) => {
  assert.equal(ref.startsWith("#"), true, `Expected a local ref, received ${ref}`)
  const pointer = decodeURIComponent(ref.slice(1))
  assert.equal(pointer.startsWith("/"), true, `Invalid local ref: ${ref}`)
  let value = document
  for (const token of pointer.slice(1).split("/")) {
    assert.equal(/~(?:[^01]|$)/.test(token), false, `Invalid JSON Pointer escape: ${ref}`)
    const key = token.replaceAll("~1", "/").replaceAll("~0", "~")
    assert.equal(value !== null && typeof value === "object" && Object.hasOwn(value, key), true, `Unresolved local ref: ${ref}`)
    value = value[key]
  }
  return value
}

const dereference = (value, document, active = new Set()) => {
  if (Array.isArray(value)) return value.map(item => dereference(item, document, active))
  if (!value || typeof value !== "object") return value
  if (typeof value.$ref === "string" && value.$ref.startsWith("#")) {
    assert.deepEqual(Object.keys(value), ["$ref"])
    assert.equal(active.has(value.$ref), false, `Recursive local ref: ${value.$ref}`)
    const nextActive = new Set(active).add(value.$ref)
    return dereference(pointerValue(document, value.$ref), document, nextActive)
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, child]) => [key, dereference(child, document, active)]),
  )
}

test("compact generation is independently valid and lossless", async t => {
  const outputDirectory = await mkdtemp(join(tmpdir(), "frontman-protocol-schemas-"))
  t.after(() => rm(outputDirectory, {recursive: true, force: true}))
  const rawPath = join(outputDirectory, "raw.json")
  const generatedDirectory = join(outputDirectory, "schemas")
  const compactPath = join(generatedDirectory, "generated.json")
  await execFileAsync(process.execPath, ["scripts/ExportSchemas.res.mjs", rawPath], {
    cwd: packageDirectory,
  })
  await execFileAsync(process.execPath, ["scripts/CompactSchemas.mjs", rawPath, generatedDirectory], {
    cwd: packageDirectory,
  })
  const raw = JSON.parse(await readFile(rawPath, "utf8"))
  const compact = JSON.parse(await readFile(compactPath, "utf8"))
  const committed = JSON.parse(await readFile(join(packageDirectory, "schemas/generated.json"), "utf8"))
  const names = Object.keys(raw.$defs)

  assert.deepEqual(await generatedTree(join(packageDirectory, "schemas")), await generatedTree(generatedDirectory))
  assert.deepEqual(committed, compact)
  assert.equal(names.length, 75)
  assert.equal(committed.$schema, "https://json-schema.org/draft/2020-12/schema")
  assert.deepEqual(
    Object.keys(committed.$defs).filter(name => !name.startsWith("shared/")),
    names,
  )

  for (const name of names) {
    const pointer = name.replaceAll("~", "~0").replaceAll("/", "~1")
    const wrapperPath = join(generatedDirectory, `${name}.json`)
    const wrapper = JSON.parse(await readFile(wrapperPath, "utf8"))
    const wrapperTarget = new URL(wrapper.$ref, pathToFileURL(wrapperPath))
    assert.equal(fileURLToPath(wrapperTarget), compactPath)
    assert.deepEqual(pointerValue(compact, wrapperTarget.hash), compact.$defs[name])
    const ajv = new Ajv2020({strict: true})
    addFormats(ajv)
    assert.doesNotThrow(() =>
      ajv.compile({$schema: committed.$schema, $defs: committed.$defs, $ref: `#/$defs/${pointer}`}),
    )
    assert.deepEqual(dereference(committed.$defs[name], committed), raw.$defs[name], name)
  }
})
