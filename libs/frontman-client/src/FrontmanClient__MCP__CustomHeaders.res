module HeaderValue = FrontmanClient__MCP__HeaderValue

type valueType = StringValue | IntegerValue | BooleanValue
type annotation = {headerName: string, path: array<string>, valueType: valueType}

let headerTokenPattern = /^[!#$%&'*+\-.^_\x60|~0-9A-Za-z]+$/

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

let annotationAt = (~path, entries): result<array<annotation>, string> =>
  switch field(entries, "x-mcp-header") {
  | None => Ok([])
  | Some(_) if path->Option.isNone => Error("x-mcp-header is not on a reachable property")
  | Some(value) =>
    switch value->asString {
    | None => Error("x-mcp-header must be a string")
    | Some(headerName) if !(headerTokenPattern->RegExp.test(headerName)) =>
      Error("x-mcp-header is not a valid field name")
    | Some(headerName) =>
      switch field(entries, "type")->Option.flatMap(asString) {
      | Some("string") => Ok([{headerName, path: path->Option.getOrThrow, valueType: StringValue}])
      | Some("integer") =>
        Ok([{headerName, path: path->Option.getOrThrow, valueType: IntegerValue}])
      | Some("boolean") =>
        Ok([{headerName, path: path->Option.getOrThrow, valueType: BooleanValue}])
      | Some(_) | None => Error("x-mcp-header property has an invalid type")
      }
    }
  }

let rec walk = (~path, ~propertiesReachable, value): result<array<annotation>, string> =>
  switch value->asObject {
  | Some(object) =>
    let entries = object->Dict.toArray
    annotationAt(~path, entries)->Result.flatMap(annotations =>
      entries->Array.reduce(Ok(annotations), (result, (key, child)) =>
        result->Result.flatMap(
          found => {
            let childResult = switch (key, propertiesReachable) {
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
                      found =>
                        walk(
                          ~path=Some(Array.concat(path->Option.getOr([]), [name])),
                          ~propertiesReachable=true,
                          schema,
                        )->Result.map(child => Array.concat(found, child)),
                    ),
                )
              | None => walk(~path=None, ~propertiesReachable=false, child)
              }
            | (_, _) => walk(~path=None, ~propertiesReachable=false, child)
            }
            childResult->Result.map(child => Array.concat(found, child))
          },
        )
      )
    )
  | None =>
    switch value->asArray {
    | Some(values) =>
      values->Array.reduce(Ok([]), (result, child) =>
        result->Result.flatMap(found =>
          walk(~path=None, ~propertiesReachable=false, child)->Result.map(
            child => Array.concat(found, child),
          )
        )
      )
    | None => Ok([])
    }
  }

let discover = schema =>
  walk(~path=None, ~propertiesReachable=true, schema)->Result.flatMap(annotations =>
    annotations->Array.reduce(Ok([]), (result, annotation) =>
      result->Result.flatMap(
        found =>
          switch found->Array.some(
            existing =>
              existing.headerName->String.toLowerCase == annotation.headerName->String.toLowerCase,
          ) {
          | true => Error("x-mcp-header names must be unique case-insensitively")
          | false => Ok(Array.concat(found, [annotation]))
          },
      )
    )
  )

let rec valueAtPath = (arguments, path) =>
  switch path[0] {
  | None => None
  | Some(name) =>
    switch arguments->Dict.get(name) {
    | None => None
    | Some(value) if JSON.stringify(value) == "null" => None
    | Some(value) if path->Array.length == 1 => Some(value)
    | Some(value) =>
      value->asObject->Option.flatMap(object => valueAtPath(object, path->Array.slice(~start=1)))
    }
  }

@scope("Number") @val external isSafeInteger: float => bool = "isSafeInteger"

let valueString = (~valueType, value) =>
  switch valueType {
  | StringValue => value->JSON.Decode.string
  | BooleanValue => value->JSON.Decode.bool->Option.map(value => value ? "true" : "false")
  | IntegerValue =>
    value
    ->JSON.Decode.float
    ->Option.flatMap(value =>
      value->isSafeInteger ? Some(JSON.stringify(JSON.Encode.float(value))) : None
    )
  }

let apply = (~headers, ~arguments, ~annotations): result<unit, string> => {
  let arguments = arguments->Option.getOr(Dict.make())
  annotations->Array.reduce(Ok(), (result, annotation) =>
    result->Result.flatMap(() =>
      switch arguments->valueAtPath(annotation.path) {
      | None => Ok()
      | Some(value) =>
        switch valueString(~valueType=annotation.valueType, value) {
        | None => Error(`Invalid value for Mcp-Param-${annotation.headerName}`)
        | Some(value) =>
          headers->Dict.set(`Mcp-Param-${annotation.headerName}`, HeaderValue.encode(value))
          Ok()
        }
      }
    )
  )
}
