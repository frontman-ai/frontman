let version = "2.0"

module ErrorCode = {
  let parseError = -32700
  let invalidRequest = -32600
  let methodNotFound = -32601
  let invalidParams = -32602
  let internalError = -32603
  let serverError = -32000
  let urlElicitationRequired = -32042
}

module Id: {
  type t

  let fromInt: int => t
  let toInt: t => option<int>
  let toJson: t => JSON.t
  let schema: S.t<t>
} = {
  type t = NumberId(float) | StringId(string)

  @scope("Number") @val
  external isSafeInteger: float => bool = "isSafeInteger"

  let fromInt = value => NumberId(Int.toFloat(value))

  let fromJson = id =>
    switch (id->JSON.Decode.string, id->JSON.Decode.float) {
    | (Some(value), _) => Some(StringId(value))
    | (_, Some(value)) if isSafeInteger(value) => Some(NumberId(value))
    | _ => None
    }

  let toInt = id =>
    switch id {
    | NumberId(value) =>
      let intValue = Float.toInt(value)
      switch Float.fromInt(intValue) == value {
      | true => Some(intValue)
      | false => None
      }
    | StringId(_) => None
    }

  let toJson = id =>
    switch id {
    | NumberId(value) => JSON.Encode.float(value)
    | StringId(value) => JSON.Encode.string(value)
    }

  let jsonSchema: JSONSchema.t = {
    anyOf: [
      JSONSchema.Schema({JSONSchema.type_: JSONSchema.Arrayable.single(#string)}),
      JSONSchema.Schema({
        JSONSchema.type_: JSONSchema.Arrayable.single(#integer),
        minimum: -9007199254740991.,
        maximum: 9007199254740991.,
      }),
    ],
  }

  let schema: S.t<t> =
    S.json
    ->S.transform(s => {
      parser: value =>
        switch value->fromJson {
        | Some(id) => id
        | None => s.fail("JSON-RPC id must be a string or safe integral number")
        },
      serializer: id => id->toJson,
    })
    ->S.extendJSONSchema(jsonSchema)
}

module RpcError: {
  type t

  let make: (~code: int, ~message: string, ~data: option<JSON.t>) => t
  let code: t => int
  let message: t => string
  let data: t => option<JSON.t>
  let schema: S.t<t>
} = {
  @schema
  type t = {
    code: int,
    message: string,
    data: option<JSON.t>,
  }

  let make = (~code: int, ~message: string, ~data: option<JSON.t>) => {
    code,
    message,
    data,
  }

  let code = t => t.code
  let message = t => t.message
  let data = t => t.data
}

module Request: {
  type t

  let make: (~id: Id.t, ~method: string, ~params: option<JSON.t>) => t
  let id: t => Id.t
  let method: t => string
  let params: t => option<JSON.t>
  let toJson: t => JSON.t
  let schema: S.t<t>
} = {
  @schema
  type t = {
    jsonrpc: string,
    id: Id.t,
    method: string,
    params: option<JSON.t>,
  }

  let make = (~id: Id.t, ~method: string, ~params: option<JSON.t>) => {
    jsonrpc: version,
    id,
    method,
    params,
  }

  let id = t => t.id
  let method = t => t.method
  let params = t => t.params
  let toJson = t => t->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
}

module Response: {
  type t

  let makeSuccess: (~id: Id.t, ~result: JSON.t) => t
  let makeSuccessPayloadWithId: (~id: Id.t, ~result: JSON.t) => JSON.t
  let makeError: (~id: Id.t, ~error: RpcError.t) => t
  let makeErrorPayloadWithId: (~id: Id.t, ~error: RpcError.t) => JSON.t
  let id: t => Id.t
  let result: t => option<JSON.t>
  let error: t => option<RpcError.t>
  let isSuccess: t => bool
  let isError: t => bool
  let fromJsonExn: JSON.t => t
  let schema: S.t<t>
} = {
  @schema
  type t = {
    jsonrpc: string,
    id: Id.t,
    result: option<JSON.t>,
    error: option<RpcError.t>,
  }

  let makeSuccess = (~id: Id.t, ~result: JSON.t) => {
    jsonrpc: version,
    id,
    result: Some(result),
    error: None,
  }

  let makeSuccessPayloadWithId = (~id: Id.t, ~result: JSON.t) =>
    JSON.Encode.object(
      Dict.fromArray([
        ("jsonrpc", JSON.Encode.string(version)),
        ("id", Id.toJson(id)),
        ("result", result),
      ]),
    )

  let makeError = (~id: Id.t, ~error: RpcError.t) => {
    jsonrpc: version,
    id,
    result: None,
    error: Some(error),
  }

  let makeErrorPayloadWithId = (~id: Id.t, ~error: RpcError.t) =>
    JSON.Encode.object(
      Dict.fromArray([
        ("jsonrpc", JSON.Encode.string(version)),
        ("id", Id.toJson(id)),
        ("error", error->S.decodeOrThrow(~from=RpcError.schema, ~to=S.json->S.noValidation(true))),
      ]),
    )

  let id = t => t.id
  let result = t => t.result
  let error = t => t.error
  let isSuccess = t => t.result->Option.isSome
  let isError = t => t.error->Option.isSome
  let fromJsonExn = json => json->S.parseOrThrow(~to=schema)
}

module Notification: {
  type t

  let make: (~method: string, ~params: option<JSON.t>) => t
  let method: t => string
  let params: t => option<JSON.t>
  let toJson: t => JSON.t
  let schema: S.t<t>
} = {
  @schema
  type t = {
    jsonrpc: string,
    method: string,
    params: option<JSON.t>,
  }

  let make = (~method: string, ~params: option<JSON.t>) => {
    jsonrpc: version,
    method,
    params,
  }

  let method = t => t.method
  let params = t => t.params
  let toJson = t => t->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
}

module Wire = {
  type requestFields = {
    jsonrpc: string,
    id: Id.t,
    method: string,
    params: option<Dict.t<JSON.t>>,
  }
  type notificationFields = {
    jsonrpc: string,
    method: string,
    params: option<Dict.t<JSON.t>>,
  }
  type resultFields = {resultType: string}
  type resultResponseFields = {
    jsonrpc: string,
    id: Id.t,
    result: resultFields,
  }
  type errorFields = {
    code: float,
    message: string,
    data: option<JSON.t>,
  }
  type errorResponseFields = {
    jsonrpc: string,
    id: option<Id.t>,
    error: errorFields,
  }

  @scope("Number") @val
  external isInteger: float => bool = "isInteger"

  let integerJsonSchema: JSONSchema.t = {
    type_: JSONSchema.Arrayable.single(#integer),
  }
  let integerSchema =
    S.float
    ->S.refine(isInteger, ~error="JSON-RPC integer must not be fractional")
    ->S.extendJSONSchema(integerJsonSchema)
  let preserveJsonWithSchema = schema =>
    S.json
    ->S.transform(_ => {
      parser: value => {
        value->S.parseOrThrow(~to=schema)->ignore
        value
      },
      serializer: value => value,
    })
    ->S.extendJSONSchema(schema->S.toJSONSchema)
  let withoutFields = (schema, fields) => {
    let forbiddenProperties = Dict.fromArray(fields->Array.map(field => (field, JSONSchema.Never)))
    let jsonSchema: JSONSchema.t = {
      allOf: [
        JSONSchema.Schema(schema->S.toJSONSchema),
        JSONSchema.Schema({properties: forbiddenProperties}),
      ],
    }

    preserveJsonWithSchema(schema)
    ->S.refine(value =>
      switch value->JSON.Decode.object {
      | Some(object) => fields->Array.every(field => !(object->Dict.has(field)))
      | None => false
      }
    , ~error="JSON-RPC message contains fields from another message type")
    ->S.extendJSONSchema(jsonSchema)
  }

  let notificationFieldsSchema = S.object(s => {
    let value: notificationFields = {
      jsonrpc: s.field("jsonrpc", S.literal("2.0")),
      method: s.field("method", S.string),
      params: s.field("params", S.option(S.dict(S.json))),
    }
    value
  })
  let requestFieldsSchema = S.object(s => {
    let value: requestFields = {
      jsonrpc: s.field("jsonrpc", S.literal("2.0")),
      id: s.field("id", Id.schema),
      method: s.field("method", S.string),
      params: s.field("params", S.option(S.dict(S.json))),
    }
    value
  })
  let resultSchema = S.object(s => {
    let value: resultFields = {
      resultType: s.field("resultType", S.string),
    }
    value
  })
  let resultResponseFieldsSchema = S.object(s => {
    let value: resultResponseFields = {
      jsonrpc: s.field("jsonrpc", S.literal("2.0")),
      id: s.field("id", Id.schema),
      result: s.field("result", resultSchema),
    }
    value
  })
  let errorSchema = S.object(s => {
    let value: errorFields = {
      code: s.field("code", integerSchema),
      message: s.field("message", S.string),
      data: s.field("data", S.option(S.json)),
    }
    value
  })
  let errorResponseFieldsSchema = S.object(s => {
    let value: errorResponseFields = {
      jsonrpc: s.field("jsonrpc", S.literal("2.0")),
      id: s.field("id", S.option(Id.schema)),
      error: s.field("error", errorSchema),
    }
    value
  })

  let requestSchema = requestFieldsSchema->withoutFields(["result", "error"])
  let notificationSchema = notificationFieldsSchema->withoutFields(["id", "result", "error"])
  let resultResponseSchema = resultResponseFieldsSchema->withoutFields(["method", "error"])
  let errorResponseSchema = errorResponseFieldsSchema->withoutFields(["method", "result"])
  let responseSchema = S.union([resultResponseSchema, errorResponseSchema])
  let messageSchema = S.union([requestSchema, notificationSchema, responseSchema])
}
