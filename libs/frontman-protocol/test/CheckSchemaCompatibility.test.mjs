import assert from "node:assert/strict"
import test from "node:test"
import {compareBundles, compareSchemas, hasProtocolMajorChangeset} from "../scripts/CheckSchemaCompatibility.mjs"

const breakingMessages = (oldSchema, currentSchema) =>
  compareSchemas(oldSchema, currentSchema).filter(issue => issue.kind === "breaking").map(issue => issue.message)

test("ignores annotations and ordering", () => {
  assert.deepEqual(
    compareSchemas(
      {title: "Old", type: "object", required: ["first", "second"], properties: {first: {enum: ["a", "b"]}}},
      {description: "New", properties: {first: {enum: ["b", "a"]}}, required: ["second", "first"], type: "object"},
    ),
    [],
  )
})

test("does not ignore annotation keywords used as property names or enum data", () => {
  const propertyIssues = compareSchemas(
    {type: "object", properties: {title: {type: "string"}, description: {type: "string"}}},
    {type: "object", properties: {title: {type: "number"}, description: {type: "boolean"}}},
  )
  assert.equal(propertyIssues.some(issue => issue.path === "#/properties/title/type" && issue.kind === "breaking"), true)
  assert.equal(propertyIssues.some(issue => issue.path === "#/properties/description/type" && issue.kind === "breaking"), true)
  assert.match(
    breakingMessages({enum: [{title: "old", description: "value"}]}, {enum: [{title: "new", description: "value"}]}).join("\n"),
    /enum\/const values removed/,
  )
  assert.match(
    breakingMessages({const: {title: "old"}}, {const: {title: "new"}}).join("\n"),
    /enum\/const values removed/,
  )
})

test("detects deleted definitions and required additions", () => {
  const issues = compareBundles(
    {deleted: {type: "string"}, kept: {type: "object", properties: {id: {type: "string"}}}},
    {kept: {type: "object", properties: {id: {type: "string"}}, required: ["id"]}},
  )
  assert.equal(issues.some(issue => issue.definition === "deleted" && issue.message === "named definition was deleted"), true)
  assert.equal(issues.some(issue => issue.definition === "kept" && issue.message === "required property added: id"), true)
})

test("detects enum and const values no longer accepted", () => {
  assert.match(breakingMessages({enum: ["a", "b"]}, {enum: ["a"]}).join("\n"), /values removed: "b"/)
  assert.match(breakingMessages({const: "a"}, {const: "b"}).join("\n"), /values removed: "a"/)
})

test("allows integer to number widening and rejects number to integer narrowing", () => {
  assert.deepEqual(compareSchemas({type: "integer"}, {type: "number"}), [])
  assert.deepEqual(compareSchemas({const: "ready"}, {type: "string", const: "ready"}), [])
  assert.match(breakingMessages({type: "number"}, {type: "integer"}).join("\n"), /accepted type removed: number/)
})

test("detects closed objects and tightened bounds", () => {
  const issues = breakingMessages(
    {type: "object", additionalProperties: true, properties: {value: {type: "string", minLength: 1}}},
    {type: "object", additionalProperties: false, properties: {value: {type: "string", minLength: 2}}},
  )
  assert.equal(issues.includes("additional properties were closed"), true)
  assert.equal(issues.includes("minLength increased"), true)
  assert.equal(breakingMessages({type: "array", maxItems: 5}, {type: "array", maxItems: 4}).includes("maxItems decreased"), true)
  assert.equal(breakingMessages({type: "number", minimum: 0}, {type: "number", exclusiveMinimum: 0}).includes("exclusiveMinimum/minimum was tightened"), true)
  assert.equal(breakingMessages({type: "number", minimum: 0}, {type: "number", minimum: 0, exclusiveMinimum: true}).includes("exclusiveMinimum/minimum was tightened"), true)
})

test("compares newly declared properties against old additionalProperties", () => {
  const fromOpen = compareSchemas(
    {type: "object"},
    {type: "object", properties: {value: {type: "string"}}},
  )
  assert.equal(fromOpen.some(issue => issue.path === "#/properties/value" && issue.kind === "breaking"), true)

  assert.deepEqual(
    compareSchemas(
      {type: "object", additionalProperties: {type: "string"}},
      {type: "object", additionalProperties: {type: "string"}, properties: {value: {type: ["string", "number"]}}},
    ),
    [],
  )
  const fromSchema = compareSchemas(
    {type: "object", additionalProperties: {type: ["string", "number"]}},
    {type: "object", additionalProperties: {type: ["string", "number"]}, properties: {value: {type: "string"}}},
  )
  assert.equal(fromSchema.some(issue => issue.path === "#/properties/value/type" && issue.kind === "breaking"), true)

  assert.deepEqual(
    compareSchemas(
      {type: "object", additionalProperties: false},
      {type: "object", additionalProperties: false, properties: {value: {type: "string"}}},
    ),
    [],
  )
})

test("detects old union branches not covered by the current union", () => {
  const issues = compareSchemas(
    {anyOf: [{type: "string"}, {type: "number"}]},
    {anyOf: [{type: "string"}, {type: "boolean"}]},
  )
  assert.equal(issues.some(issue => issue.kind === "breaking" && issue.path === "#/anyOf/1"), true)
})

test("reports unsupported complex narrowing as unknown", () => {
  const issues = compareSchemas({type: "string"}, {type: "string", pattern: "^[a-z]+$"})
  assert.deepEqual(issues, [{kind: "unknown", path: "#/pattern", message: "unsupported schema keyword changed: pattern"}])
})

test("resolves equivalent relocated refs with JSON Pointer escaping", () => {
  const oldDefinitions = {
    api: {
      type: "object",
      properties: {
        local: {$ref: "#/$defs/value~1with~0escape"},
        shared: {$ref: "#/$defs/shared~1old~0value"},
      },
      $defs: {"value/with~escape": {type: "string", minLength: 1}},
    },
    "shared/old~value": {type: "string", minLength: 1},
  }
  const currentDefinitions = {
    api: {
      type: "object",
      properties: {
        local: {$ref: "#/$defs/shared~1new-value"},
        shared: {$ref: "#/$defs/shared~1new-value"},
      },
    },
    "shared/new-value": {minLength: 1, type: "string"},
  }
  assert.deepEqual(compareBundles(oldDefinitions, currentDefinitions), [])
})

test("reports unresolved local refs as unknown", () => {
  const issues = compareBundles(
    {api: {type: "object", properties: {value: {type: "string"}}}},
    {api: {type: "object", properties: {value: {$ref: "#/$defs/missing~1value"}}}},
  )
  assert.equal(issues.some(issue => issue.kind === "unknown" && issue.message === "unresolved local $ref: #/$defs/missing~1value"), true)
})

test("reports recursive local ref cycles as unknown", () => {
  const definitions = {
    api: {$ref: "#/$defs/node"},
    node: {type: "object", properties: {child: {$ref: "#/$defs/node"}}},
  }
  const issues = compareBundles(definitions, definitions)
  assert.equal(issues.some(issue => issue.kind === "unknown" && issue.message === "recursive local $ref cycle: #/$defs/node"), true)
})

test("only an explicit protocol major changeset authorizes failures", () => {
  assert.equal(hasProtocolMajorChangeset([{content: "---\n\"@frontman-ai/frontman-protocol\": major\n---\n\nBreak it.\n"}]), true)
  assert.equal(hasProtocolMajorChangeset([{content: "---\n\"@frontman-ai/frontman-protocol\": minor\n\"other\": major\n---\n"}]), false)
  assert.equal(hasProtocolMajorChangeset([{content: "A sentence mentioning @frontman-ai/frontman-protocol and major."}]), false)
  assert.equal(
    hasProtocolMajorChangeset([{content: "---\nnotes: |\n  \"@frontman-ai/frontman-protocol\": major\n---\n"}]),
    false,
  )
  assert.equal(
    hasProtocolMajorChangeset([{content: "---\n  \"@frontman-ai/frontman-protocol\": major\n---\n"}]),
    false,
  )
})
