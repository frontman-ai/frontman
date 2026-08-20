import {createHash} from "node:crypto"
import {mkdir, readFile, writeFile} from "node:fs/promises"
import {dirname, join, relative, sep} from "node:path"
import Ajv2020 from "ajv/dist/2020.js"
import addFormats from "ajv-formats"

const [inputPath, outputDirectory] = process.argv.slice(2)

if (!inputPath || !outputDirectory) {
  throw new Error("Usage: CompactSchemas.mjs <input-path> <output-directory>")
}

const bundle = JSON.parse(await readFile(inputPath, "utf8"))
const definitions = bundle.$defs

if (!definitions || typeof definitions !== "object" || Array.isArray(definitions)) {
  throw new Error("Input bundle has no $defs object")
}

const mapKeywords = new Set([
  "$defs",
  "definitions",
  "dependentSchemas",
  "patternProperties",
  "properties",
])
const arrayKeywords = new Set(["allOf", "anyOf", "oneOf", "prefixItems"])
const singleKeywords = new Set([
  "additionalItems",
  "additionalProperties",
  "contains",
  "contentSchema",
  "else",
  "if",
  "items",
  "not",
  "propertyNames",
  "then",
  "unevaluatedItems",
  "unevaluatedProperties",
])

const isSchema = value =>
  typeof value === "boolean" || (value !== null && typeof value === "object" && !Array.isArray(value))

const canonicalize = value => {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalize).join(",")}]`
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map(key => `${JSON.stringify(key)}:${canonicalize(value[key])}`)
      .join(",")}}`
  }
  return JSON.stringify(value)
}

const visitChildren = (schema, visit) => {
  if (!schema || typeof schema !== "object" || Array.isArray(schema)) {
    return
  }
  for (const [keyword, value] of Object.entries(schema)) {
    if (mapKeywords.has(keyword) && value && typeof value === "object" && !Array.isArray(value)) {
      for (const child of Object.values(value)) {
        if (isSchema(child)) visit(child)
      }
    } else if (arrayKeywords.has(keyword) && Array.isArray(value)) {
      for (const child of value) {
        if (isSchema(child)) visit(child)
      }
    } else if (singleKeywords.has(keyword)) {
      if (Array.isArray(value) && keyword === "items") {
        for (const child of value) {
          if (isSchema(child)) visit(child)
        }
      } else if (isSchema(value)) {
        visit(value)
      }
    } else if (keyword === "dependencies" && value && typeof value === "object") {
      for (const child of Object.values(value)) {
        if (isSchema(child)) visit(child)
      }
    }
  }
}

const schemasByCanonical = new Map()
const counts = new Map()
const strictAjv = new Ajv2020({strict: true})
addFormats(strictAjv)
const compilesIndependently = schema => {
  try {
    strictAjv.compile(schema)
    return true
  } catch {
    return false
  }
}
const countSchemas = schema => {
  const canonical = canonicalize(schema)
  schemasByCanonical.set(canonical, schema)
  counts.set(canonical, (counts.get(canonical) ?? 0) + 1)
  visitChildren(schema, countSchemas)
}

for (const schema of Object.values(definitions)) {
  countSchemas(schema)
}

const pointer = name => name.replaceAll("~", "~0").replaceAll("/", "~1")
const rootOwner = new Map()

for (const [name, schema] of Object.entries(definitions)) {
  const canonical = canonicalize(schema)
  if (!rootOwner.has(canonical)) rootOwner.set(canonical, name)
}

const candidates = new Map()
const sharedSchemas = new Map()
const hashes = new Map()

for (const canonical of [...counts.keys()].sort()) {
  const count = counts.get(canonical)
  if (count < 2) continue
  const schema = schemasByCanonical.get(canonical)
  if (!compilesIndependently(schema)) continue
  const owner = rootOwner.get(canonical)
  if (owner) {
    const refSize = JSON.stringify({$ref: `#/$defs/${pointer(owner)}`}).length
    if (canonical.length > refSize) candidates.set(canonical, owner)
    continue
  }
  const hash = createHash("sha256").update(canonical).digest("hex").slice(0, 16)
  const previous = hashes.get(hash)
  if (previous && previous !== canonical) throw new Error(`Shared schema hash collision: ${hash}`)
  hashes.set(hash, canonical)
  const name = `shared/${hash}`
  const refSize = JSON.stringify({$ref: `#/$defs/${pointer(name)}`}).length
  const definitionCost = canonical.length + JSON.stringify(name).length + 1
  if (count * canonical.length > definitionCost + count * refSize) {
    candidates.set(canonical, name)
    sharedSchemas.set(name, schema)
  }
}

const referenced = new Set()
const render = (schema, suppressedCanonical) => {
  const canonical = canonicalize(schema)
  const candidate = candidates.get(canonical)
  if (candidate && canonical !== suppressedCanonical) {
    referenced.add(candidate)
    return {$ref: `#/$defs/${pointer(candidate)}`}
  }
  if (!schema || typeof schema !== "object" || Array.isArray(schema)) return schema
  const rendered = {}
  for (const [keyword, value] of Object.entries(schema)) {
    if (mapKeywords.has(keyword) && value && typeof value === "object" && !Array.isArray(value)) {
      rendered[keyword] = Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, isSchema(child) ? render(child) : child]),
      )
    } else if (arrayKeywords.has(keyword) && Array.isArray(value)) {
      rendered[keyword] = value.map(child => (isSchema(child) ? render(child) : child))
    } else if (singleKeywords.has(keyword)) {
      if (Array.isArray(value) && keyword === "items") {
        rendered[keyword] = value.map(child => (isSchema(child) ? render(child) : child))
      } else {
        rendered[keyword] = isSchema(value) ? render(value) : value
      }
    } else if (keyword === "dependencies" && value && typeof value === "object") {
      rendered[keyword] = Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, isSchema(child) ? render(child) : child]),
      )
    } else {
      rendered[keyword] = value
    }
  }
  return rendered
}

const compactDefinitions = {}
for (const [name, schema] of Object.entries(definitions)) {
  const canonical = canonicalize(schema)
  compactDefinitions[name] = render(schema, candidates.get(canonical) === name ? canonical : undefined)
}

const pending = [...referenced].filter(name => sharedSchemas.has(name)).sort()
const queuedShared = new Set(pending)
const emittedShared = new Set()
for (let index = 0; index < pending.length; index += 1) {
  const name = pending[index]
  if (emittedShared.has(name)) continue
  emittedShared.add(name)
  const schema = sharedSchemas.get(name)
  const canonical = canonicalize(schema)
  compactDefinitions[name] = render(schema, canonical)
  for (const referencedName of [...referenced].sort()) {
    if (sharedSchemas.has(referencedName) && !queuedShared.has(referencedName)) {
      queuedShared.add(referencedName)
      pending.push(referencedName)
    }
  }
}

const definitionRefs = new Set(
  Object.keys(compactDefinitions).map(name => `#/$defs/${pointer(name)}`),
)
const assertRefsResolve = value => {
  if (Array.isArray(value)) {
    value.forEach(assertRefsResolve)
  } else if (value && typeof value === "object") {
    if (typeof value.$ref === "string" && value.$ref.startsWith("#/$defs/") && !definitionRefs.has(value.$ref)) {
      throw new Error(`Unresolved local schema reference: ${value.$ref}`)
    }
    Object.values(value).forEach(assertRefsResolve)
  }
}
assertRefsResolve(compactDefinitions)

await mkdir(outputDirectory, {recursive: true})
const generatedPath = join(outputDirectory, "generated.json")
await writeFile(
  generatedPath,
  `${JSON.stringify({$schema: "https://json-schema.org/draft/2020-12/schema", $defs: compactDefinitions}, null, 2)}\n`,
)

await Promise.all(
  Object.keys(definitions).map(async name => {
    const wrapperPath = join(outputDirectory, `${name}.json`)
    await mkdir(dirname(wrapperPath), {recursive: true})
    const generatedRelativePath = relative(dirname(wrapperPath), generatedPath).split(sep).join("/")
    const wrapper = {
      $schema: "https://json-schema.org/draft/2020-12/schema",
      $ref: `${generatedRelativePath}#/$defs/${pointer(name)}`,
    }
    await writeFile(wrapperPath, `${JSON.stringify(wrapper, null, 2)}\n`)
  }),
)
