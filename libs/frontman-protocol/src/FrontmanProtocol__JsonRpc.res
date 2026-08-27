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
  let schema: S.t<t>
} = {
  type t = IntId(int) | StringId(string)

  let fromInt = value => IntId(value)

  let toInt = id =>
    switch id {
    | IntId(value) => Some(value)
    | StringId(_) => None
    }

  let schema: S.t<t> = S.union([
    S.float
    ->S.refine(value => Float.fromInt(Float.toInt(value)) == value, ~error="Expected integer")
    ->S.extendJSONSchema(S.int->S.toJSONSchema)
    ->S.transform(s => {
      parser: value => IntId(Float.toInt(value)),
      serializer: id =>
        switch id {
        | IntId(value) => Float.fromInt(value)
        | StringId(_) => s.fail("Expected integer JSON-RPC id")
        },
    }),
    S.string->S.transform(s => {
      parser: value => StringId(value),
      serializer: id =>
        switch id {
        | StringId(value) => value
        | IntId(_) => s.fail("Expected string JSON-RPC id")
        },
    }),
  ])
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
    jsonrpc: @s.matches(S.literal("2.0")) string,
    id: @s.matches(Id.schema) Id.t,
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
  let makeError: (~id: Id.t, ~error: RpcError.t) => t
  let makeErrorWithoutId: (~error: RpcError.t) => t
  let id: t => option<Id.t>
  let result: t => option<JSON.t>
  let error: t => option<RpcError.t>
  let isSuccess: t => bool
  let isError: t => bool
  let toJson: t => JSON.t
  let fromJsonExn: JSON.t => t
  let schema: S.t<t>
} = {
  type t =
    | Success({id: Id.t, result: JSON.t, error: option<S.never>})
    | Error({id: option<Id.t>, error: RpcError.t, result: option<S.never>})

  let schema = S.union([
    S.object(s => {
      s.tag("jsonrpc", "2.0")
      let id = s.field("id", Id.schema)
      let result = s.field("result", S.json)
      let error = s.field("error", S.option(S.never))
      Success({id, result, error})
    }),
    S.object(s => {
      s.tag("jsonrpc", "2.0")
      let id = s.field("id", S.option(Id.schema))
      let error = s.field("error", RpcError.schema)
      let result = s.field("result", S.option(S.never))
      Error({id, error, result})
    }),
  ])

  let makeSuccess = (~id: Id.t, ~result: JSON.t) => Success({id, result, error: None})
  let makeError = (~id: Id.t, ~error: RpcError.t) => Error({id: Some(id), error, result: None})
  let makeErrorWithoutId = (~error: RpcError.t) => Error({id: None, error, result: None})

  let id = t =>
    switch t {
    | Success({id}) => Some(id)
    | Error({id}) => id
    }
  let result = t =>
    switch t {
    | Success({result}) => Some(result)
    | Error(_) => None
    }
  let error = t =>
    switch t {
    | Success(_) => None
    | Error({error}) => Some(error)
    }
  let isSuccess = t =>
    switch t {
    | Success(_) => true
    | Error(_) => false
    }
  let isError = t => !isSuccess(t)
  let toJson = t => t->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))
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
    jsonrpc: @s.matches(S.literal("2.0")) string,
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
