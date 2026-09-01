type validator = JSON.t => bool
type ajv

type ajvOptions = {
  @live
  strict: bool,
  @live
  allErrors: bool,
  @live
  validateFormats: bool,
}

@module("ajv/dist/2020.js") @new
external makeAjv2020: ajvOptions => ajv = "default"

@module("ajv") @new
external makeAjvDraft7: ajvOptions => ajv = "default"

@module("ajv-formats")
external addFormats: ajv => unit = "default"

@send external compile: (ajv, JSON.t) => validator = "compile"
@send external addKeyword: (ajv, string) => ajv = "addKeyword"

type limits = {
  maxDepth: int,
  maxSubschemas: int,
}

let defaultLimits = {maxDepth: 32, maxSubschemas: 1024}
let draft202012 = "https://json-schema.org/draft/2020-12/schema"
let draft202012WithHash = draft202012 ++ "#"
let draft7 = "http://json-schema.org/draft-07/schema#"
let draft7Https = "https://json-schema.org/draft-07/schema#"

let asObject = value => {
  try {
    Some(value->S.parseOrThrow(~to=S.dict(S.json)))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let asArray = value => {
  try {
    Some(value->S.parseOrThrow(~to=S.array(S.json)))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let rec measure = (value, ~depth, ~count, ~limits): result<int, string> => {
  let nextCount = switch (value->asObject, value->asArray) {
  | (Some(_), _) | (_, Some(_)) => count + 1
  | (None, None) => count
  }
  switch (depth > limits.maxDepth, nextCount > limits.maxSubschemas) {
  | (true, _) => Error("Schema exceeds maximum depth")
  | (_, true) => Error("Schema exceeds maximum subschema count")
  | (false, false) =>
    switch value->asObject {
    | Some(object) =>
      object
      ->Dict.toArray
      ->Array.reduce(Ok(nextCount), (result, (_key, child)) =>
        result->Result.flatMap(next => measure(child, ~depth=depth + 1, ~count=next, ~limits))
      )
    | None =>
      switch value->asArray {
      | Some(values) =>
        values->Array.reduce(Ok(nextCount), (result, child) =>
          result->Result.flatMap(next => measure(child, ~depth=depth + 1, ~count=next, ~limits))
        )
      | None => Ok(nextCount)
      }
    }
  }
}

let dialect = schema =>
  schema
  ->asObject
  ->Option.flatMap(object => object->Dict.get("$schema"))
  ->Option.flatMap(JSON.Decode.string)

let makeAjv = schema => {
  let options = {strict: true, allErrors: true, validateFormats: true}
  switch dialect(schema) {
  | None =>
    let ajv = makeAjv2020(options)
    addFormats(ajv)
    ajv->addKeyword("x-mcp-header")->ignore
    Ok(ajv)
  | Some(value) if value == draft202012 || value == draft202012WithHash =>
    let ajv = makeAjv2020(options)
    addFormats(ajv)
    ajv->addKeyword("x-mcp-header")->ignore
    Ok(ajv)
  | Some(value) if value == draft7 || value == draft7Https =>
    let ajv = makeAjvDraft7(options)
    addFormats(ajv)
    ajv->addKeyword("x-mcp-header")->ignore
    Ok(ajv)
  | Some(value) => Error(`Unsupported JSON Schema dialect: ${value}`)
  }
}

let compileSchema = (~schema, ~limits=defaultLimits): result<validator, string> =>
  measure(schema, ~depth=0, ~count=0, ~limits)->Result.flatMap(_ =>
    makeAjv(schema)->Result.flatMap(ajv => {
      try {
        Ok(ajv->compile(schema))
      } catch {
      | exn =>
        Error(
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Invalid JSON Schema"),
        )
      }
    })
  )

let validateValue = (~schema, ~value): result<unit, string> =>
  compileSchema(~schema)->Result.flatMap(validator =>
    switch validator(value) {
    | true => Ok()
    | false => Error("Value does not match JSON Schema")
    }
  )
