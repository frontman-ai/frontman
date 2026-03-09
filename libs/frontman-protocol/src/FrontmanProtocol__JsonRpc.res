// JSON-RPC 2.0 message types for ACP communication

S.enableJson()

let version = "2.0"

// Standard error codes (named constants for convenience)
module ErrorCode = {
  let parseError = -32700
  let invalidRequest = -32600
  let methodNotFound = -32601
  let invalidParams = -32602
  let internalError = -32603
  // -32000 to -32099: reserved for server errors (used by task_channel for agent errors)
  let serverError = -32000
  // ACP elicitation: URL mode elicitation is required before the request can proceed
  let urlElicitationRequired = -32042
}

// JSON-RPC Error
// Uses int for code to accept any valid JSON-RPC error code (including server-defined ones
// in the -32000..-32099 range). A restrictive enum previously caused parse failures when
// the server sent -32000, silently dropping error responses and leaving prompts unresolved.
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

// JSON-RPC Request
module Request: {
  type t

  let make: (~id: int, ~method: string, ~params: option<JSON.t>) => t
  let id: t => int
  let method: t => string
  let params: t => option<JSON.t>
  let toJson: t => JSON.t
  let schema: S.t<t>
} = {
  @schema
  type t = {
    jsonrpc: string,
    id: int,
    method: string,
    params: option<JSON.t>,
  }

  let make = (~id: int, ~method: string, ~params: option<JSON.t>) => {
    jsonrpc: version,
    id,
    method,
    params,
  }

  let id = t => t.id
  let method = t => t.method
  let params = t => t.params
  let toJson = t => t->S.reverseConvertToJsonOrThrow(schema)
}

// JSON-RPC Response
module Response: {
  type t

  let makeSuccess: (~id: int, ~result: JSON.t) => t
  let makeError: (~id: int, ~error: RpcError.t) => t
  let id: t => int
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
    id: int,
    result: option<JSON.t>,
    error: option<RpcError.t>,
  }

  let makeSuccess = (~id: int, ~result: JSON.t) => {
    jsonrpc: version,
    id,
    result: Some(result),
    error: None,
  }

  let makeError = (~id: int, ~error: RpcError.t) => {
    jsonrpc: version,
    id,
    result: None,
    error: Some(error),
  }

  let id = t => t.id
  let result = t => t.result
  let error = t => t.error
  let isSuccess = t => t.result->Option.isSome
  let isError = t => t.error->Option.isSome
  let fromJsonExn = json => json->S.parseOrThrow(schema)
}

// JSON-RPC Notification (no id, no response expected)
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
  let toJson = t => t->S.reverseConvertToJsonOrThrow(schema)
}
