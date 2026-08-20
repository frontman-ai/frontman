open Vitest

module CustomHeaders = FrontmanCore__MCP__CustomHeaders
module RawHeaders = FrontmanCore__MCP__RawHeaders

external jsonAsSchema: JSON.t => JSONSchema.t = "%identity"

let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)
let schema = source => source->json->jsonAsSchema
let arguments = source => source->json->S.parseOrThrow(~to=S.dict(S.json))->Some
let rawHeaders = entries => RawHeaders.make(entries)

let annotation = (~headerName, ~path, ~valueType): CustomHeaders.annotation => {
  headerName,
  path,
  valueType,
}

describe("MCP custom parameter headers", _t => {
  test("discovers primitive annotations only through properties paths", t => {
    let annotations = CustomHeaders.discover(
      schema(`{
        "type":"object",
        "properties":{
          "region":{"type":"string","x-mcp-header":"Region"},
          "options":{"type":"object","properties":{
            "count":{"type":"integer","x-mcp-header":"Count"},
            "enabled":{"type":"boolean","x-mcp-header":"Enabled"}
          }}
        }
      }`),
    )->Result.getOrThrow

    t
    ->expect(annotations)
    ->Expect.toEqual([
      annotation(~headerName="Region", ~path=["region"], ~valueType=CustomHeaders.StringValue),
      annotation(
        ~headerName="Count",
        ~path=["options", "count"],
        ~valueType=CustomHeaders.IntegerValue,
      ),
      annotation(
        ~headerName="Enabled",
        ~path=["options", "enabled"],
        ~valueType=CustomHeaders.BooleanValue,
      ),
    ])
    t->expect(CustomHeaders.discover(schema(`{"type":"object"}`)))->Expect.toEqual(Ok([]))
  })

  test("rejects invalid annotation names, values, types, and duplicates", t => {
    let assertError = (~property, ~expected) =>
      t
      ->expect(
        CustomHeaders.discover(schema(`{"type":"object","properties":{"value":${property}}}`)),
      )
      ->Expect.toEqual(Error(expected))

    assertError(
      ~property=`{"type":"string","x-mcp-header":1}`,
      ~expected=CustomHeaders.InvalidAnnotationValue,
    )
    assertError(
      ~property=`{"type":"string","x-mcp-header":""}`,
      ~expected=CustomHeaders.InvalidAnnotationName,
    )
    assertError(
      ~property=`{"type":"string","x-mcp-header":"Bad Name"}`,
      ~expected=CustomHeaders.InvalidAnnotationName,
    )
    assertError(
      ~property=`{"type":"string","x-mcp-header":"Bad:Name"}`,
      ~expected=CustomHeaders.InvalidAnnotationName,
    )
    assertError(
      ~property=`{"type":"number","x-mcp-header":"Value"}`,
      ~expected=CustomHeaders.InvalidAnnotatedType,
    )
    assertError(
      ~property=`{"type":["string","null"],"x-mcp-header":"Value"}`,
      ~expected=CustomHeaders.InvalidAnnotatedType,
    )

    let duplicate = schema(`{
      "type":"object",
      "properties":{
        "first":{"type":"string","x-mcp-header":"Region"},
        "second":{"type":"string","x-mcp-header":"region"}
      }
    }`)
    t
    ->expect(CustomHeaders.discover(duplicate))
    ->Expect.toEqual(Error(CustomHeaders.DuplicateAnnotationName))
  })

  test("rejects annotations outside statically reachable properties", t => {
    let invalidSchemas = [
      `{"type":"object","x-mcp-header":"Root"}`,
      `{"type":"object","items":{"type":"string","x-mcp-header":"Item"}}`,
      `{"type":"object","prefixItems":[{"type":"string","x-mcp-header":"Prefix"}]}`,
      `{"type":"object","oneOf":[{"type":"string","x-mcp-header":"Choice"}]}`,
      `{"type":"object","anyOf":[{"type":"string","x-mcp-header":"Choice"}]}`,
      `{"type":"object","allOf":[{"type":"string","x-mcp-header":"Choice"}]}`,
      `{"type":"object","not":{"type":"string","x-mcp-header":"Not"}}`,
      `{"type":"object","if":{"type":"string","x-mcp-header":"Conditional"}}`,
      `{"type":"object","then":{"type":"string","x-mcp-header":"Conditional"}}`,
      `{"type":"object","else":{"type":"string","x-mcp-header":"Conditional"}}`,
      `{"type":"object","$ref":{"type":"string","x-mcp-header":"Ref"}}`,
      `{"type":"object","$defs":{"hidden":{"type":"string","x-mcp-header":"Ref"}}}`,
      `{"type":"object","vendor":{"properties":{"value":{"type":"string","x-mcp-header":"Hidden"}}}}`,
    ]

    invalidSchemas->Array.forEach(
      source =>
        t
        ->expect(CustomHeaders.discover(schema(source)))
        ->Expect.toEqual(Error(CustomHeaders.InvalidAnnotationLocation)),
    )
  })

  test("matches decoded strings, booleans, and safe integral JSON numbers", _t => {
    let annotations = [
      annotation(~headerName="Region", ~path=["region"], ~valueType=CustomHeaders.StringValue),
      annotation(~headerName="Enabled", ~path=["enabled"], ~valueType=CustomHeaders.BooleanValue),
      annotation(~headerName="Count", ~path=["count"], ~valueType=CustomHeaders.IntegerValue),
    ]
    let assertValid = (~region, ~enabled, ~count) =>
      CustomHeaders.validate(
        ~rawHeaders=rawHeaders([
          ("mcp-param-region", region),
          ("MCP-PARAM-ENABLED", enabled),
          ("Mcp-Param-Count", count),
        ]),
        ~arguments=arguments(`{"region":"café","enabled":true,"count":42}`),
        ~annotations,
      )->Result.getOrThrow

    assertValid(~region="=?base64?Y2Fmw6k=?=", ~enabled="true", ~count="42")
    assertValid(~region="=?base64?Y2Fmw6k=?=", ~enabled="true", ~count="42.0")
    assertValid(~region="=?base64?Y2Fmw6k=?=", ~enabled="true", ~count="4.2e1")
  })

  test("preserves commas and encoded control or edge whitespace in string values", _t => {
    let annotation = annotation(
      ~headerName="Value",
      ~path=["value"],
      ~valueType=CustomHeaders.StringValue,
    )
    let assertValid = (~body, ~header) =>
      CustomHeaders.validate(
        ~rawHeaders=rawHeaders([("Mcp-Param-Value", header)]),
        ~arguments=arguments(body),
        ~annotations=[annotation],
      )->Result.getOrThrow

    assertValid(~body=`{"value":"a, b"}`, ~header="a, b")
    assertValid(~body=`{"value":" line "}`, ~header="=?base64?IGxpbmUg?=")
    assertValid(~body=`{"value":"line\\n"}`, ~header="=?base64?bGluZQo=?=")
  })

  test("rejects duplicate recognized physical fields without splitting singleton commas", t => {
    let annotation = annotation(
      ~headerName="Value",
      ~path=["value"],
      ~valueType=CustomHeaders.StringValue,
    )
    let assertMismatch = entries =>
      t
      ->expect(
        CustomHeaders.validate(
          ~rawHeaders=rawHeaders(entries),
          ~arguments=arguments(`{"value":"a, b"}`),
          ~annotations=[annotation],
        ),
      )
      ->Expect.toEqual(Error(CustomHeaders.HeaderMismatch("Mcp-Param-Value")))

    CustomHeaders.validate(
      ~rawHeaders=rawHeaders([("mCp-PaRaM-vAlUe", "a, b")]),
      ~arguments=arguments(`{"value":"a, b"}`),
      ~annotations=[annotation],
    )->Result.getOrThrow
    assertMismatch([("Mcp-Param-Value", "a"), ("mcp-param-value", "b")])
    assertMismatch([("Mcp-Param-Value", "a, b"), ("MCP-PARAM-VALUE", "a, b")])
  })

  test("rejects malformed flat Node header input as an adapter invariant", t => {
    let crashed = try {
      RawHeaders.fromFlatArray(["Mcp-Param-Value"])->ignore
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("Node raw headers contained an unmatched field name")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })

  test("accepts boolean false and both safe integer boundaries", _t => {
    let annotations = [
      annotation(~headerName="Enabled", ~path=["enabled"], ~valueType=CustomHeaders.BooleanValue),
      annotation(~headerName="Count", ~path=["count"], ~valueType=CustomHeaders.IntegerValue),
    ]
    let assertValid = (~body, ~count) =>
      CustomHeaders.validate(
        ~rawHeaders=rawHeaders([("Mcp-Param-Enabled", "false"), ("Mcp-Param-Count", count)]),
        ~arguments=arguments(body),
        ~annotations,
      )->Result.getOrThrow

    assertValid(~body=`{"enabled":false,"count":9007199254740991}`, ~count="9007199254740991")
    assertValid(~body=`{"enabled":false,"count":-9007199254740991}`, ~count="-9007199254740991.0")
    assertValid(
      ~body=`{"enabled":false,"count":1}`,
      ~count="1" ++ "0"->String.repeat(101) ++ "e-101",
    )
  })

  test("requires omission exactly for absent, null, or unreachable values", t => {
    let annotation = annotation(
      ~headerName="Region",
      ~path=["options", "region"],
      ~valueType=CustomHeaders.StringValue,
    )
    let noHeaders = rawHeaders([])
    let assertValid = arguments =>
      CustomHeaders.validate(
        ~rawHeaders=noHeaders,
        ~arguments,
        ~annotations=[annotation],
      )->Result.getOrThrow

    assertValid(None)
    assertValid(arguments(`{}`))
    assertValid(arguments(`{"options":null}`))
    assertValid(arguments(`{"options":true}`))
    assertValid(arguments(`{"options":{"region":null}}`))

    t
    ->expect(
      CustomHeaders.validate(
        ~rawHeaders=rawHeaders([("Mcp-Param-Region", "us-east1")]),
        ~arguments=None,
        ~annotations=[annotation],
      ),
    )
    ->Expect.toEqual(Error(CustomHeaders.HeaderMismatch("Mcp-Param-Region")))
  })

  test("rejects missing, malformed, unsafe, wrong-type, and unequal values", t => {
    let assertMismatch = (~valueType, ~body, ~header) => {
      let annotation = annotation(~headerName="Value", ~path=["value"], ~valueType)
      t
      ->expect(
        CustomHeaders.validate(
          ~rawHeaders=header->Option.mapOr(
            rawHeaders([]),
            value => rawHeaders([("Mcp-Param-Value", value)]),
          ),
          ~arguments=arguments(body),
          ~annotations=[annotation],
        ),
      )
      ->Expect.toEqual(Error(CustomHeaders.HeaderMismatch("Mcp-Param-Value")))
    }

    assertMismatch(~valueType=CustomHeaders.StringValue, ~body=`{"value":"x"}`, ~header=None)
    assertMismatch(~valueType=CustomHeaders.StringValue, ~body=`{"value":"x"}`, ~header=Some("y"))
    assertMismatch(
      ~valueType=CustomHeaders.StringValue,
      ~body=`{"value":"x"}`,
      ~header=Some("=?base64?abc?="),
    )
    assertMismatch(
      ~valueType=CustomHeaders.BooleanValue,
      ~body=`{"value":true}`,
      ~header=Some("TRUE"),
    )
    assertMismatch(~valueType=CustomHeaders.IntegerValue, ~body=`{"value":42}`, ~header=Some("+42"))
    assertMismatch(
      ~valueType=CustomHeaders.IntegerValue,
      ~body=`{"value":42}`,
      ~header=Some("42.5"),
    )
    assertMismatch(
      ~valueType=CustomHeaders.IntegerValue,
      ~body=`{"value":42}`,
      ~header=Some("42.0000000000000001"),
    )
    assertMismatch(
      ~valueType=CustomHeaders.IntegerValue,
      ~body=`{"value":9007199254740992}`,
      ~header=Some("9007199254740992"),
    )
    assertMismatch(
      ~valueType=CustomHeaders.IntegerValue,
      ~body=`{"value":-9007199254740992}`,
      ~header=Some("-9007199254740992"),
    )
    assertMismatch(
      ~valueType=CustomHeaders.IntegerValue,
      ~body=`{"value":"42"}`,
      ~header=Some("42"),
    )
  })

  test("ignores unrecognized custom headers", _t => {
    CustomHeaders.validate(
      ~rawHeaders=rawHeaders([("Mcp-Param-Unrecognized", "anything")]),
      ~arguments=arguments(`{"value":"anything"}`),
      ~annotations=[],
    )->Result.getOrThrow
  })
})
