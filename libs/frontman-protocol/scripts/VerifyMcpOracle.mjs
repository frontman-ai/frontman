import {createHash} from "node:crypto"
import {readdir, readFile} from "node:fs/promises"
import {dirname, isAbsolute, join, relative, resolve, sep} from "node:path"
import {fileURLToPath} from "node:url"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const upstreamRoot = join(packageRoot, "test/mcp-upstream")

export const sha256 = value => createHash("sha256").update(value).digest("hex")

const files = async directory => {
  const entries = await readdir(directory, {withFileTypes: true})
  const paths = await Promise.all(entries.map(entry => {
    const path = join(directory, entry.name)
    if (entry.isSymbolicLink()) {
      throw new Error(`Oracle contains a symbolic link: ${path}`)
    }
    return entry.isDirectory() ? files(path) : [path]
  }))
  return paths.flat().sort()
}

export const verifyChecksums = async root => {
  const manifest = await readFile(join(root, "SHA256SUMS"), "utf8")
  const entries = manifest.trim().split("\n").map(line => {
    const match = line.match(/^([0-9a-f]{64})  (.+)$/)
    if (match === null) {
      throw new Error(`Malformed checksum entry: ${line}`)
    }
    const [, expected, path] = match
    const parts = path.split("/")
    if (isAbsolute(path) || parts.some(part => part === "" || part === "." || part === "..")) {
      throw new Error(`Invalid checksum path: ${path}`)
    }
    return {expected, path, parts}
  })
  const manifestPaths = entries.map(entry => entry.path)
  if (new Set(manifestPaths).size !== manifestPaths.length) {
    throw new Error("Checksum manifest contains duplicate paths")
  }
  const artifactPaths = (await files(root))
    .map(path => relative(root, path).split(sep).join("/"))
    .filter(path => path !== "README.md" && path !== "SHA256SUMS")
  if (JSON.stringify([...manifestPaths].sort()) !== JSON.stringify(artifactPaths)) {
    throw new Error("Checksum manifest does not match oracle artifacts")
  }
  for (const {expected, path, parts} of entries) {
    const contents = await readFile(join(root, ...parts))
    if (sha256(contents) !== expected) {
      throw new Error(`Checksum mismatch: ${path}`)
    }
  }
}

const jsonFiles = async directory => {
  return (await files(directory)).filter(path => path.endsWith(".json"))
}

export const createOracle = schema => {
  const ajv = new Ajv2020({allErrors: true, allowUnionTypes: true, strict: true})
  addFormats(ajv)
  ajv.compile(schema)
  const validators = new Map()
  return {
    validate(definition, value) {
      if (!(definition in schema.$defs)) {
        throw new Error(`Unknown upstream definition: ${definition}`)
      }
      if (!validators.has(definition)) {
        validators.set(definition, ajv.compile({
          $schema: schema.$schema,
          $defs: schema.$defs,
          $ref: `#/$defs/${definition}`,
        }))
      }
      const validate = validators.get(definition)
      return {valid: validate(value), errors: validate.errors}
    },
  }
}

export const verifyExamples = async root => {
  const schema = JSON.parse(await readFile(join(root, "schema.json"), "utf8"))
  const oracle = createOracle(schema)
  const examplesRoot = join(root, "examples")
  const paths = await jsonFiles(examplesRoot)
  for (const path of paths) {
    const definition = relative(examplesRoot, path).split(sep)[0]
    const value = JSON.parse(await readFile(path, "utf8"))
    const result = oracle.validate(definition, value)
    if (!result.valid) {
      throw new Error(`${relative(root, path)} failed ${definition}: ${JSON.stringify(result.errors)}`)
    }
  }
  return paths.length
}

export const verifyOracle = async root => {
  await verifyChecksums(root)
  return verifyExamples(root)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const count = await verifyOracle(upstreamRoot)
  process.stdout.write(`Verified MCP 2026-07-28 oracle and ${count} official examples.\n`)
}
