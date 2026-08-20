module HeaderValue = FrontmanCore__MCP__HeaderValue
module RawHeaders = FrontmanCore__MCP__RawHeaders

type valueType =
  | StringValue
  | IntegerValue
  | BooleanValue

type annotation = {
  headerName: string,
  path: array<string>,
  valueType: valueType,
}

type schemaError =
  | InvalidAnnotationValue
  | InvalidAnnotationName
  | DuplicateAnnotationName
  | InvalidAnnotationLocation
  | InvalidAnnotatedType

type validationError = HeaderMismatch(string)

type argumentValue =
  | Absent
  | Present(JSON.t)

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

@scope("Number") @val
external isSafeInteger: float => bool = "isSafeInteger"

let headerTokenPattern = /^[!#$%&'*+\-.^_\x60|~0-9A-Za-z]+$/
let jsonNumberPattern = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/

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

let asString = value => {
  try {
    Some(value->S.parseOrThrow(~to=S.string))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let field = (entries, name) =>
  entries->Array.findMap(((key, value)) => key == name ? Some(value) : None)

let annotationAt = (~path, entries): result<array<annotation>, schemaError> => {
  switch field(entries, "x-mcp-header") {
  | None => Ok([])
  | Some(_) if path->Option.isNone => Error(InvalidAnnotationLocation)
  | Some(value) =>
    switch value->asString {
    | None => Error(InvalidAnnotationValue)
    | Some(headerName) if !(headerTokenPattern->RegExp.test(headerName)) =>
      Error(InvalidAnnotationName)
    | Some(headerName) =>
      switch field(entries, "type")->Option.flatMap(asString) {
      | Some("string") => Ok([{headerName, path: path->Option.getOrThrow, valueType: StringValue}])
      | Some("integer") =>
        Ok([{headerName, path: path->Option.getOrThrow, valueType: IntegerValue}])
      | Some("boolean") =>
        Ok([{headerName, path: path->Option.getOrThrow, valueType: BooleanValue}])
      | Some(_) | None => Error(InvalidAnnotatedType)
      }
    }
  }
}

let rec walk = (~path, ~propertiesReachable, value): result<array<annotation>, schemaError> => {
  switch value->asObject {
  | Some(object) =>
    let entries = object->Dict.toArray
    annotationAt(~path, entries)->Result.flatMap(annotations =>
      entries->Array.reduce(Ok(annotations), (result, (key, child)) =>
        result->Result.flatMap(
          annotations => {
            let found = switch (key, propertiesReachable) {
            | ("x-mcp-header", _) => Ok([])
            | ("properties", true) =>
              switch child->asObject {
              | Some(properties) =>
                properties
                ->Dict.toArray
                ->Array.reduce(
                  Ok([]),
                  (result, (name, schema)) =>
                    result->Result.flatMap(
                      annotations =>
                        walk(
                          ~path=Some(Array.concat(path->Option.getOr([]), [name])),
                          ~propertiesReachable=true,
                          schema,
                        )->Result.map(found => Array.concat(annotations, found)),
                    ),
                )
              | None => walk(~path=None, ~propertiesReachable=false, child)
              }
            | (_, _) => walk(~path=None, ~propertiesReachable=false, child)
            }
            found->Result.map(found => Array.concat(annotations, found))
          },
        )
      )
    )
  | None =>
    switch value->asArray {
    | Some(values) =>
      values->Array.reduce(Ok([]), (result, value) =>
        result->Result.flatMap(annotations =>
          walk(~path=None, ~propertiesReachable=false, value)->Result.map(
            found => Array.concat(annotations, found),
          )
        )
      )
    | None => Ok([])
    }
  }
}

let discover = (schema: JSONSchema.t): result<array<annotation>, schemaError> => {
  walk(
    ~path=None,
    ~propertiesReachable=true,
    schema->jsonSchemaAsJson,
  )->Result.flatMap(annotations =>
    annotations->Array.reduce(Ok([]), (result, annotation) =>
      result->Result.flatMap(
        unique => {
          let normalized = annotation.headerName->String.toLowerCase
          switch unique->Array.some(
            existing => existing.headerName->String.toLowerCase == normalized,
          ) {
          | true => Error(DuplicateAnnotationName)
          | false => Ok(Array.concat(unique, [annotation]))
          }
        },
      )
    )
  )
}

let isNull = value => {
  try {
    value->S.parseOrThrow(~to=S.literal(JSON.Encode.null))->ignore
    true
  } catch {
  | S.Exn(_) => false
  | exn => throw(exn)
  }
}

let rec argumentAtPath = (arguments, path): argumentValue => {
  switch path[0] {
  | None => Absent
  | Some(name) =>
    switch arguments->Dict.get(name) {
    | None => Absent
    | Some(value) if isNull(value) => Absent
    | Some(value) if path->Array.length == 1 => Present(value)
    | Some(value) =>
      switch value->asObject {
      | Some(object) => argumentAtPath(object, path->Array.slice(~start=1))
      | None => Absent
      }
    }
  }
}

let parseBodyBoolean = value => {
  try {
    Some(value->S.parseOrThrow(~to=S.bool))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let parseBodyInteger = value => {
  try {
    let value = value->S.parseOrThrow(~to=S.float)
    value->isSafeInteger ? Some(value) : None
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let hasExactIntegerSyntax = value => {
  let exponentIndex = switch value->String.indexOf("e") {
  | -1 => value->String.indexOf("E")
  | index => index
  }
  let (mantissa, exponent) = switch exponentIndex {
  | -1 => (value, 0.0)
  | index => (
      value->String.slice(~start=0, ~end=index),
      value->String.slice(~start=index + 1)->Float.fromString->Option.getOrThrow,
    )
  }
  let unsignedMantissa =
    mantissa->String.startsWith("-") ? mantissa->String.slice(~start=1) : mantissa
  let decimalIndex = unsignedMantissa->String.indexOf(".")
  let (digits, fractionLength) = switch decimalIndex {
  | -1 => (unsignedMantissa, 0)
  | index => (
      unsignedMantissa->String.slice(~start=0, ~end=index) ++
        unsignedMantissa->String.slice(~start=index + 1),
      unsignedMantissa->String.length - index - 1,
    )
  }

  switch /^0+$/->RegExp.test(digits) {
  | true => true
  | false
    if !(exponent->isSafeInteger) ||
    exponent > Int.toFloat(digits->String.length + fractionLength + 16) ||
    exponent < -Int.toFloat(digits->String.length + fractionLength + 16) => false
  | false =>
    let scale = Int.fromFloat(exponent) - fractionLength
    switch scale >= 0 {
    | true => true
    | false =>
      let requiredZeros = -scale
      requiredZeros <= digits->String.length &&
        digits->String.endsWith("0"->String.repeat(requiredZeros))
    }
  }
}

let parseHeaderInteger = value => {
  switch jsonNumberPattern->RegExp.test(value) && hasExactIntegerSyntax(value) {
  | false => None
  | true =>
    try {
      let value = value->S.decodeOrThrow(~from=S.jsonString, ~to=S.float)
      value->isSafeInteger ? Some(value) : None
    } catch {
    | S.Exn(_) => None
    | exn => throw(exn)
    }
  }
}

let valueMatches = (~valueType, ~body, ~header) => {
  switch HeaderValue.decode(header) {
  | Error(_) => false
  | Ok(header) =>
    switch valueType {
    | StringValue => body->asString == Some(header)
    | BooleanValue =>
      switch body->parseBodyBoolean {
      | Some(true) => header == "true"
      | Some(false) => header == "false"
      | None => false
      }
    | IntegerValue =>
      switch (body->parseBodyInteger, header->parseHeaderInteger) {
      | (Some(body), Some(header)) => body == header
      | (Some(_), None) | (None, Some(_)) | (None, None) => false
      }
    }
  }
}

let validate = (
  ~rawHeaders: RawHeaders.t,
  ~arguments: option<Dict.t<JSON.t>>,
  ~annotations: array<annotation>,
): result<unit, validationError> => {
  let arguments = arguments->Option.getOr(Dict.make())
  annotations->Array.reduce(Ok(), (result, annotation) =>
    result->Result.flatMap(() => {
      let headerName = `Mcp-Param-${annotation.headerName}`
      switch rawHeaders->RawHeaders.values(~name=headerName) {
      | [] =>
        switch argumentAtPath(arguments, annotation.path) {
        | Absent => Ok()
        | Present(_) => Error(HeaderMismatch(headerName))
        }
      | [header] =>
        switch argumentAtPath(arguments, annotation.path) {
        | Present(body) if valueMatches(~valueType=annotation.valueType, ~body, ~header) => Ok()
        | Absent | Present(_) => Error(HeaderMismatch(headerName))
        }
      | _ => Error(HeaderMismatch(headerName))
      }
    })
  )
}
