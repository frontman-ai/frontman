import assert from "node:assert/strict"
import {execFile} from "node:child_process"
import {readdir, readFile} from "node:fs/promises"
import {dirname, join, relative, sep} from "node:path"
import {promisify} from "node:util"
import {fileURLToPath, pathToFileURL} from "node:url"

const execFileAsync = promisify(execFile)
const annotationKeywords = new Set([
  "$comment",
  "$id",
  "$schema",
  "default",
  "deprecated",
  "description",
  "examples",
  "readOnly",
  "title",
  "writeOnly",
])
const handledKeywords = new Set([
  "$ref",
  "additionalProperties",
  "anyOf",
  "const",
  "enum",
  "exclusiveMaximum",
  "exclusiveMinimum",
  "items",
  "maxItems",
  "maxLength",
  "maxProperties",
  "maximum",
  "minItems",
  "minLength",
  "minProperties",
  "minimum",
  "properties",
  "required",
  "type",
  "uniqueItems",
])
const setArrayKeywords = new Set(["allOf", "anyOf", "enum", "oneOf", "required", "type"])
const schemaMapKeywords = new Set(["$defs", "definitions", "dependentSchemas", "patternProperties", "properties"])
const schemaArrayKeywords = new Set(["allOf", "anyOf", "oneOf", "prefixItems"])
const schemaSingleKeywords = new Set([
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

const issue = (kind, path, message) => ({kind, path, message})
const jsonEqual = (left, right) => {
  try {
    assert.deepStrictEqual(normalize(left), normalize(right))
    return true
  } catch {
    return false
  }
}
const dataEqual = (left, right) => {
  try {
    assert.deepStrictEqual(normalize(left, "", "data"), normalize(right, "", "data"))
    return true
  } catch {
    return false
  }
}

function normalize(value, key = "", context = "schema") {
  if (Array.isArray(value)) {
    const childContext = context === "data" || key === "enum" ? "data" : "schema"
    const normalized = value.map(item => normalize(item, "", childContext))
    return setArrayKeywords.has(key)
      ? normalized.toSorted((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)))
      : normalized
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value)
    if (context === "data") {
      return Object.fromEntries(
        entries
          .sort(([left], [right]) => left.localeCompare(right))
          .map(([entryKey, entryValue]) => [entryKey, normalize(entryValue, entryKey, "data")]),
      )
    }
    if (context === "schemaMap") {
      return Object.fromEntries(
        entries
          .sort(([left], [right]) => left.localeCompare(right))
          .map(([entryKey, entryValue]) => [entryKey, normalize(entryValue, entryKey, "schema")]),
      )
    }
    return Object.fromEntries(
      entries
        .filter(([entryKey]) => !annotationKeywords.has(entryKey))
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([entryKey, entryValue]) => {
          const childContext = entryKey === "const" || entryKey === "enum"
            ? "data"
            : schemaMapKeywords.has(entryKey)
              ? "schemaMap"
              : "schema"
          return [entryKey, normalize(entryValue, entryKey, childContext)]
        }),
    )
  }
  return value
}

const acceptedValues = schema => {
  if (Object.hasOwn(schema, "const")) return [schema.const]
  if (Array.isArray(schema.enum)) return schema.enum
  return null
}

const typeList = schema => {
  if (typeof schema.type === "string") return [schema.type]
  if (Array.isArray(schema.type) && schema.type.every(type => typeof type === "string")) return schema.type
  return null
}

const typeCovered = (oldType, currentTypes) =>
  currentTypes.includes(oldType) || (oldType === "integer" && currentTypes.includes("number"))

const valueMatchesType = (value, type) => {
  if (type === "null") return value === null
  if (type === "array") return Array.isArray(value)
  if (type === "object") return value !== null && typeof value === "object" && !Array.isArray(value)
  if (type === "integer") return Number.isInteger(value)
  if (type === "number") return typeof value === "number"
  return typeof value === type
}

function compareUnion(oldSchema, currentSchema, path) {
  const oldBranches = oldSchema.anyOf ?? [oldSchema]
  const currentBranches = currentSchema.anyOf ?? [currentSchema]
  const issues = []
  for (const [index, oldBranch] of oldBranches.entries()) {
    const candidates = currentBranches.map(currentBranch => compareSchemas(oldBranch, currentBranch, path))
    if (candidates.some(candidate => candidate.length === 0)) continue
    const kind = candidates.every(candidate => candidate.some(candidateIssue => candidateIssue.kind === "breaking"))
      ? "breaking"
      : "unknown"
    issues.push(issue(kind, `${path}/anyOf/${index}`, "old union branch is not covered by the current schema"))
  }
  const oldOuter = {...oldSchema}
  const currentOuter = {...currentSchema}
  delete oldOuter.anyOf
  delete currentOuter.anyOf
  if (Object.keys(oldOuter).length > 0 || Object.keys(currentOuter).length > 0) {
    issues.push(...compareSimpleSchemas(oldOuter, currentOuter, path))
  }
  return issues
}

function compareLowerBound(oldSchema, currentSchema, inclusiveKeyword, exclusiveKeyword, path) {
  const oldNumericExclusive = typeof oldSchema[exclusiveKeyword] === "number"
  const currentNumericExclusive = typeof currentSchema[exclusiveKeyword] === "number"
  const oldExclusive = oldNumericExclusive || oldSchema[exclusiveKeyword] === true
  const currentExclusive = currentNumericExclusive || currentSchema[exclusiveKeyword] === true
  const oldValue = oldNumericExclusive ? oldSchema[exclusiveKeyword] : oldSchema[inclusiveKeyword]
  const currentValue = currentNumericExclusive ? currentSchema[exclusiveKeyword] : currentSchema[inclusiveKeyword]
  if (currentValue === undefined) return []
  if (oldValue === undefined || currentValue > oldValue || (currentValue === oldValue && currentExclusive && !oldExclusive)) {
    return [issue("breaking", path, `${exclusiveKeyword}/${inclusiveKeyword} was tightened`)]
  }
  return []
}

function compareUpperBound(oldSchema, currentSchema, inclusiveKeyword, exclusiveKeyword, path) {
  const oldNumericExclusive = typeof oldSchema[exclusiveKeyword] === "number"
  const currentNumericExclusive = typeof currentSchema[exclusiveKeyword] === "number"
  const oldExclusive = oldNumericExclusive || oldSchema[exclusiveKeyword] === true
  const currentExclusive = currentNumericExclusive || currentSchema[exclusiveKeyword] === true
  const oldValue = oldNumericExclusive ? oldSchema[exclusiveKeyword] : oldSchema[inclusiveKeyword]
  const currentValue = currentNumericExclusive ? currentSchema[exclusiveKeyword] : currentSchema[inclusiveKeyword]
  if (currentValue === undefined) return []
  if (oldValue === undefined || currentValue < oldValue || (currentValue === oldValue && currentExclusive && !oldExclusive)) {
    return [issue("breaking", path, `${exclusiveKeyword}/${inclusiveKeyword} was tightened`)]
  }
  return []
}

function compareMinimum(oldSchema, currentSchema, keyword, path) {
  if (currentSchema[keyword] === undefined) return []
  if (oldSchema[keyword] === undefined || currentSchema[keyword] > oldSchema[keyword]) {
    return [issue("breaking", path, `${keyword} increased`)]
  }
  return []
}

function compareMaximum(oldSchema, currentSchema, keyword, path) {
  if (currentSchema[keyword] === undefined) return []
  if (oldSchema[keyword] === undefined || currentSchema[keyword] < oldSchema[keyword]) {
    return [issue("breaking", path, `${keyword} decreased`)]
  }
  return []
}

function compareSimpleSchemas(oldSchema, currentSchema, path) {
  if (jsonEqual(oldSchema, currentSchema)) return []
  const issues = []
  const oldTypes = typeList(oldSchema)
  const currentTypes = typeList(currentSchema)
  const oldValues = acceptedValues(oldSchema)
  const currentValues = acceptedValues(currentSchema)
  if (currentTypes && !oldTypes) {
    if (!oldValues || oldValues.some(value => !currentTypes.some(type => valueMatchesType(value, type)))) {
      issues.push(issue("breaking", `${path}/type`, "type constraint was added"))
    }
  } else if (oldTypes && currentTypes) {
    const removedTypes = oldTypes.filter(oldType => !typeCovered(oldType, currentTypes))
    if (removedTypes.length > 0) {
      issues.push(issue("breaking", `${path}/type`, `accepted type removed: ${removedTypes.join(", ")}`))
    }
  }

  if (currentValues && !oldValues) {
    issues.push(issue("breaking", `${path}/enum`, "enum/const constraint was added"))
  } else if (oldValues && currentValues) {
    const removedValues = oldValues.filter(oldValue => !currentValues.some(value => dataEqual(value, oldValue)))
    if (removedValues.length > 0) {
      issues.push(issue("breaking", `${path}/enum`, `enum/const values removed: ${removedValues.map(JSON.stringify).join(", ")}`))
    }
  }

  const oldRequired = new Set(oldSchema.required ?? [])
  for (const name of currentSchema.required ?? []) {
    if (!oldRequired.has(name)) issues.push(issue("breaking", `${path}/required`, `required property added: ${name}`))
  }

  const oldAdditional = oldSchema.additionalProperties ?? true
  const currentAdditional = currentSchema.additionalProperties ?? true
  if (oldAdditional !== false && currentAdditional === false) {
    issues.push(issue("breaking", `${path}/additionalProperties`, "additional properties were closed"))
  } else if (oldAdditional !== false && currentAdditional && typeof currentAdditional === "object") {
    if (oldAdditional === true) {
      issues.push(issue("breaking", `${path}/additionalProperties`, "additional properties were restricted"))
    } else {
      issues.push(...compareSchemas(oldAdditional, currentAdditional, `${path}/additionalProperties`))
    }
  }

  for (const [name, oldProperty] of Object.entries(oldSchema.properties ?? {})) {
    const propertyPath = `${path}/properties/${name}`
    if (Object.hasOwn(currentSchema.properties ?? {}, name)) {
      issues.push(...compareSchemas(oldProperty, currentSchema.properties[name], propertyPath))
    } else if (currentAdditional === false) {
      issues.push(issue("breaking", propertyPath, "previously accepted property is no longer allowed"))
    } else if (currentAdditional && typeof currentAdditional === "object") {
      issues.push(...compareSchemas(oldProperty, currentAdditional, propertyPath))
    }
  }

  for (const [name, currentProperty] of Object.entries(currentSchema.properties ?? {})) {
    if (Object.hasOwn(oldSchema.properties ?? {}, name) || oldAdditional === false) continue
    const oldProperty = oldAdditional === true ? true : oldAdditional
    issues.push(...compareSchemas(oldProperty, currentProperty, `${path}/properties/${name}`))
  }

  if (Object.hasOwn(currentSchema, "items")) {
    if (!Object.hasOwn(oldSchema, "items")) {
      if (currentSchema.items !== true) issues.push(issue("breaking", `${path}/items`, "array items were restricted"))
    } else {
      issues.push(...compareSchemas(oldSchema.items, currentSchema.items, `${path}/items`))
    }
  }

  issues.push(...compareLowerBound(oldSchema, currentSchema, "minimum", "exclusiveMinimum", path))
  issues.push(...compareUpperBound(oldSchema, currentSchema, "maximum", "exclusiveMaximum", path))
  for (const keyword of ["minLength", "minItems", "minProperties"]) {
    issues.push(...compareMinimum(oldSchema, currentSchema, keyword, path))
  }
  for (const keyword of ["maxLength", "maxItems", "maxProperties"]) {
    issues.push(...compareMaximum(oldSchema, currentSchema, keyword, path))
  }
  if (currentSchema.uniqueItems === true && oldSchema.uniqueItems !== true) {
    issues.push(issue("breaking", `${path}/uniqueItems`, "uniqueItems was enabled"))
  }

  const allKeywords = new Set([...Object.keys(oldSchema), ...Object.keys(currentSchema)])
  for (const keyword of allKeywords) {
    if (annotationKeywords.has(keyword) || handledKeywords.has(keyword)) continue
    if (currentSchema[keyword] === undefined || jsonEqual(oldSchema[keyword], currentSchema[keyword])) continue
    issues.push(issue("unknown", `${path}/${keyword}`, `unsupported schema keyword changed: ${keyword}`))
  }
  return issues
}

export function compareSchemas(oldSchema, currentSchema, path = "#") {
  if (jsonEqual(oldSchema, currentSchema)) return []
  if (oldSchema === false) return []
  if (currentSchema === true) return []
  if (oldSchema === true || currentSchema === false) {
    return [issue("breaking", path, "current schema accepts fewer values")]
  }
  if (!oldSchema || !currentSchema || typeof oldSchema !== "object" || typeof currentSchema !== "object") {
    return [issue("unknown", path, "unsupported non-object schema change")]
  }
  if (oldSchema.anyOf || currentSchema.anyOf) return compareUnion(oldSchema, currentSchema, path)
  return compareSimpleSchemas(oldSchema, currentSchema, path)
}

const pointerTokens = ref => {
  if (!ref.startsWith("#")) return null
  let pointer
  try {
    pointer = decodeURIComponent(ref.slice(1))
  } catch {
    return null
  }
  if (pointer === "") return []
  if (!pointer.startsWith("/")) return null
  const tokens = []
  for (const token of pointer.slice(1).split("/")) {
    if (/~(?:[^01]|$)/.test(token)) return null
    tokens.push(token.replaceAll("~1", "/").replaceAll("~0", "~"))
  }
  return tokens
}

const pointerValue = (document, tokens) => {
  let value = document
  for (const token of tokens) {
    if (!value || typeof value !== "object" || !Object.hasOwn(value, token)) return {found: false}
    value = value[token]
  }
  return {found: true, value}
}

function resolveDefinitionReferences(schema, definitions) {
  const bundleDocument = {$defs: definitions}
  const issues = []
  const cache = new Map()
  const active = new Set()

  const resolve = (value, path) => {
    if (typeof value === "boolean" || !value || typeof value !== "object" || Array.isArray(value)) return value
    if (typeof value.$ref === "string") {
      const validatingSiblings = Object.keys(value).filter(
        keyword => keyword !== "$ref" && keyword !== "$defs" && keyword !== "definitions" && !annotationKeywords.has(keyword),
      )
      if (validatingSiblings.length > 0) {
        issues.push(issue("unknown", `${path}/$ref`, `unsupported validating $ref siblings: ${validatingSiblings.join(", ")}`))
        return value
      }
      const tokens = pointerTokens(value.$ref)
      if (!tokens) {
        issues.push(issue("unknown", `${path}/$ref`, `unresolved local $ref: ${value.$ref}`))
        return value
      }
      const localTarget = pointerValue(schema, tokens)
      const bundleTarget = localTarget.found ? localTarget : pointerValue(bundleDocument, tokens)
      if (!bundleTarget.found) {
        issues.push(issue("unknown", `${path}/$ref`, `unresolved local $ref: ${value.$ref}`))
        return value
      }
      const scope = localTarget.found ? "document" : "definitions"
      const cacheKey = `${scope}:${value.$ref}`
      if (active.has(cacheKey)) {
        issues.push(issue("unknown", `${path}/$ref`, `recursive local $ref cycle: ${value.$ref}`))
        return value
      }
      if (cache.has(cacheKey)) return cache.get(cacheKey)
      active.add(cacheKey)
      const resolved = resolve(bundleTarget.value, path)
      active.delete(cacheKey)
      cache.set(cacheKey, resolved)
      return resolved
    }

    const resolved = {}
    for (const [keyword, child] of Object.entries(value)) {
      if (keyword === "$defs" || keyword === "definitions") continue
      if (schemaMapKeywords.has(keyword) && child && typeof child === "object" && !Array.isArray(child)) {
        resolved[keyword] = Object.fromEntries(
          Object.entries(child).map(([name, nested]) => [name, resolve(nested, `${path}/${keyword}/${name}`)]),
        )
      } else if (schemaArrayKeywords.has(keyword) && Array.isArray(child)) {
        resolved[keyword] = child.map((nested, index) => resolve(nested, `${path}/${keyword}/${index}`))
      } else if (schemaSingleKeywords.has(keyword)) {
        if (keyword === "items" && Array.isArray(child)) {
          resolved[keyword] = child.map((nested, index) => resolve(nested, `${path}/${keyword}/${index}`))
        } else {
          resolved[keyword] = resolve(child, `${path}/${keyword}`)
        }
      } else if (keyword === "dependencies" && child && typeof child === "object" && !Array.isArray(child)) {
        resolved[keyword] = Object.fromEntries(
          Object.entries(child).map(([name, nested]) => [
            name,
            Array.isArray(nested) ? nested : resolve(nested, `${path}/${keyword}/${name}`),
          ]),
        )
      } else {
        resolved[keyword] = child
      }
    }
    return resolved
  }

  return {schema: resolve(schema, "#"), issues}
}

export function compareBundles(oldDefinitions, currentDefinitions) {
  const results = []
  for (const [name, oldSchema] of Object.entries(oldDefinitions)) {
    if (name.startsWith("shared/")) continue
    if (!Object.hasOwn(currentDefinitions, name)) {
      results.push({definition: name, ...issue("breaking", "#", "named definition was deleted")})
      continue
    }
    const oldResolved = resolveDefinitionReferences(oldSchema, oldDefinitions)
    const currentResolved = resolveDefinitionReferences(currentDefinitions[name], currentDefinitions)
    for (const resolutionIssue of [...oldResolved.issues, ...currentResolved.issues]) {
      results.push({definition: name, ...resolutionIssue})
    }
    for (const schemaIssue of compareSchemas(oldResolved.schema, currentResolved.schema)) {
      results.push({definition: name, ...schemaIssue})
    }
  }
  return results
}

export function hasProtocolMajorChangeset(changesets) {
  return changesets.some(({content}) => {
    const lines = content.split(/\r?\n/)
    if (lines[0] !== "---") return false
    const entries = new Map()
    for (let index = 1; index < lines.length; index += 1) {
      const line = lines[index]
      if (line === "---") return entries.get("@frontman-ai/frontman-protocol") === "major"
      if (line === "") continue
      const match = line.match(/^(?:"([^"\r\n]+)"|'([^'\r\n]+)'|([A-Za-z0-9@_./-]+)):[ \t]*(?:"([^"\r\n]+)"|'([^'\r\n]+)'|([A-Za-z0-9_-]+))[ \t]*$/)
      if (!match) return false
      const key = match[1] ?? match[2] ?? match[3]
      const value = match[4] ?? match[5] ?? match[6]
      if (entries.has(key)) return false
      entries.set(key, value)
    }
    return false
  })
}

function definitionsFromBundle(bundle) {
  const definitions = bundle.$defs ?? bundle.definitions ?? bundle.schemas
  if (definitions && !Array.isArray(definitions) && typeof definitions === "object") return definitions
  if (Array.isArray(bundle)) return Object.fromEntries(bundle.map(entry => [entry.name, entry.schema]))
  throw new Error("generated.json must contain $defs, definitions, schemas, or named schema entries")
}

async function currentDefinitions(schemasDirectory) {
  try {
    return definitionsFromBundle(JSON.parse(await readFile(join(schemasDirectory, "generated.json"), "utf8")))
  } catch (error) {
    if (error.code !== "ENOENT") throw error
  }
  const definitions = {}
  const visit = async directory => {
    for (const entry of await readdir(directory, {withFileTypes: true})) {
      const path = join(directory, entry.name)
      if (entry.isDirectory()) {
        if (entry.name !== "upstream") await visit(path)
      } else if (entry.name.endsWith(".json")) {
        const name = relative(schemasDirectory, path).split(sep).join("/").replace(/\.json$/, "")
        definitions[name] = JSON.parse(await readFile(path, "utf8"))
      }
    }
  }
  await visit(schemasDirectory)
  return definitions
}

async function git(repoRoot, args) {
  return (await execFileAsync("git", args, {cwd: repoRoot, maxBuffer: 50 * 1024 * 1024})).stdout
}

async function baselineDefinitions(repoRoot, baseline, schemasRelative) {
  const paths = (await git(repoRoot, ["ls-tree", "-r", "--name-only", baseline, "--", schemasRelative]))
    .trim()
    .split("\n")
    .filter(Boolean)
  const generatedPath = `${schemasRelative}/generated.json`
  if (paths.includes(generatedPath)) {
    return definitionsFromBundle(JSON.parse(await git(repoRoot, ["show", `${baseline}:${generatedPath}`])))
  }
  const definitions = {}
  for (const path of paths.filter(path => path.endsWith(".json") && !path.includes("/upstream/"))) {
    const name = path.slice(schemasRelative.length + 1).replace(/\.json$/, "")
    definitions[name] = JSON.parse(await git(repoRoot, ["show", `${baseline}:${path}`]))
  }
  return definitions
}

async function changedChangesets(repoRoot, baseline) {
  const paths = (await git(repoRoot, ["diff", "--name-only", "--diff-filter=AM", baseline, "--", ".changeset/*.md"]))
    .trim()
    .split("\n")
    .filter(Boolean)
  return Promise.all(paths.map(async path => ({path, content: await readFile(join(repoRoot, path), "utf8")})))
}

export async function run({repoRoot, baseline = "origin/main", stdout = console.log, stderr = console.error}) {
  const schemasRelative = "libs/frontman-protocol/schemas"
  const oldDefinitions = await baselineDefinitions(repoRoot, baseline, schemasRelative)
  const newDefinitions = await currentDefinitions(join(repoRoot, schemasRelative))
  const issues = compareBundles(oldDefinitions, newDefinitions)
  if (issues.length === 0) {
    stdout("Protocol schemas are backward compatible.")
    return 0
  }
  stdout("=== Protocol Schema Compatibility Report ===")
  for (const result of issues) {
    stdout(`${result.kind.toUpperCase()} ${result.definition}${result.path === "#" ? "" : result.path.slice(1)}: ${result.message}`)
  }
  const changesets = await changedChangesets(repoRoot, baseline)
  if (hasProtocolMajorChangeset(changesets)) {
    const authorizing = changesets.filter(changeset => hasProtocolMajorChangeset([changeset])).map(changeset => changeset.path)
    stdout(`Intentional breaking changes accepted by protocol major changeset: ${authorizing.join(", ")}`)
    return 0
  }
  stderr("Protocol schema compatibility failed. Add an explicit major changeset for @frontman-ai/frontman-protocol only for intentional breaking changes.")
  return 1
}

const scriptPath = fileURLToPath(import.meta.url)
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const repoRoot = join(dirname(scriptPath), "../../..")
  process.exitCode = await run({repoRoot})
}
