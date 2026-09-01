open Vitest

module JsonSchema = FrontmanCore__MCP__JsonSchema

let nestedAnnotation = depth =>
  `{"x-frontman-test":${"["->String.repeat(depth - 1)}null${"]"->String.repeat(
      depth - 1,
    )}}`->JSON.parseOrThrow

let schemaWithNodes = nodes => {
  let children = Array.make(~length=nodes - 2, JSON.Encode.object(Dict.make()))
  JSON.Encode.object(Dict.fromArray([("x-frontman-test", JSON.Encode.array(children))]))
}

let compileOrThrow = schema =>
  switch JsonSchema.compile(schema) {
  | JsonSchema.Valid(validator) => validator
  | JsonSchema.Invalid => failwith("Expected valid bounded schema")
  }

let compiled = result =>
  switch result {
  | JsonSchema.Valid(_) => true
  | JsonSchema.Invalid => false
  }

describe("bounded MCP JSON Schema 2020-12 validation", _t => {
  test("enforces exact schema depth and node boundaries", t => {
    t
    ->expect(JsonSchema.compile(nestedAnnotation(JsonSchema.schemaDepthLimit))->compiled)
    ->Expect.toBe(true)
    t
    ->expect(JsonSchema.compile(nestedAnnotation(JsonSchema.schemaDepthLimit + 1)))
    ->Expect.toEqual(JsonSchema.Invalid)
    t
    ->expect(JsonSchema.compile(schemaWithNodes(JsonSchema.schemaNodeLimit))->compiled)
    ->Expect.toBe(true)
    t
    ->expect(JsonSchema.compile(schemaWithNodes(JsonSchema.schemaNodeLimit + 1)))
    ->Expect.toEqual(JsonSchema.Invalid)
  })

  test("allows same-document references and rejects every external resolver path", t => {
    let local = JSON.parseOrThrow(`{"$defs":{"value":{"type":"string"}},"$ref":"#/$defs/value"}`)
    let validator = local->compileOrThrow
    t->expect(validator->JsonSchema.validate(JSON.Encode.string("ok")))->Expect.toBe(true)
    t->expect(validator->JsonSchema.validate(JSON.Encode.int(1)))->Expect.toBe(false)

    [
      "https://example.com/schema",
      "http://127.0.0.1/schema",
      "file:///tmp/schema",
      "data:application/schema+json,{}",
      "other.json#/$defs/value",
    ]->Array.forEach(
      reference =>
        t
        ->expect(JsonSchema.compile(JSON.parseOrThrow(`{"$ref":"${reference}"}`)))
        ->Expect.toEqual(JsonSchema.Invalid),
    )
  })

  test("enforces exact instance depth, node, and UTF-8 byte boundaries", t => {
    let validator = JSON.parseOrThrow(`{}`)->compileOrThrow
    let nested = depth =>
      `${"["->String.repeat(depth)}null${"]"->String.repeat(depth)}`->JSON.parseOrThrow
    t
    ->expect(validator->JsonSchema.validate(nested(JsonSchema.instanceDepthLimit)))
    ->Expect.toBe(true)
    t
    ->expect(validator->JsonSchema.validate(nested(JsonSchema.instanceDepthLimit + 1)))
    ->Expect.toBe(false)

    let atNodeLimit = JSON.Encode.array(
      Array.make(~length=JsonSchema.instanceNodeLimit - 1, JSON.Encode.object(Dict.make())),
    )
    let overNodeLimit = JSON.Encode.array(
      Array.make(~length=JsonSchema.instanceNodeLimit, JSON.Encode.object(Dict.make())),
    )
    t->expect(validator->JsonSchema.validate(atNodeLimit))->Expect.toBe(true)
    t->expect(validator->JsonSchema.validate(overNodeLimit))->Expect.toBe(false)

    t
    ->expect(
      validator->JsonSchema.validate(
        JSON.Encode.string("x"->String.repeat(JsonSchema.instanceByteLimit - 2)),
      ),
    )
    ->Expect.toBe(true)
    t
    ->expect(
      validator->JsonSchema.validate(
        JSON.Encode.string("x"->String.repeat(JsonSchema.instanceByteLimit - 1)),
      ),
    )
    ->Expect.toBe(false)
  })
})
