open Vitest

module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc

describe("JsonRpc Request", _t => {
  test("make creates request with correct fields", t => {
    let req = JsonRpc.Request.make(~id=1, ~method="test", ~params=None)

    t->expect(req->JsonRpc.Request.id)->Expect.toEqual(1)
    t->expect(req->JsonRpc.Request.method)->Expect.toEqual("test")
    t->expect(req->JsonRpc.Request.params)->Expect.toEqual(None)
  })

  test("toJson produces valid JSON-RPC 2.0 structure", t => {
    let req = JsonRpc.Request.make(~id=42, ~method="initialize", ~params=None)
    let json = req->JsonRpc.Request.toJson
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("jsonrpc"))->Expect.toEqual(Some(JSON.Encode.string("2.0")))
    t->expect(obj->Dict.get("id"))->Expect.toEqual(Some(JSON.Encode.int(42)))
    t->expect(obj->Dict.get("method"))->Expect.toEqual(Some(JSON.Encode.string("initialize")))
  })

  test("toJson includes params when provided", t => {
    let paramsDict = Dict.make()
    paramsDict->Dict.set("key", JSON.Encode.string("value"))
    let params = JSON.Encode.object(paramsDict)

    let req = JsonRpc.Request.make(~id=1, ~method="test", ~params=Some(params))
    let json = req->JsonRpc.Request.toJson
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("params")->Option.isSome)->Expect.toEqual(true)
  })
})

describe("JsonRpc Response", _t => {
  test("makeSuccess creates successful response", t => {
    let result = JSON.Encode.string("success")
    let resp = JsonRpc.Response.makeSuccess(~id=1, ~result)

    t->expect(resp->JsonRpc.Response.id)->Expect.toEqual(1)
    t->expect(resp->JsonRpc.Response.isSuccess)->Expect.toEqual(true)
    t->expect(resp->JsonRpc.Response.isError)->Expect.toEqual(false)
    t->expect(resp->JsonRpc.Response.result)->Expect.toEqual(Some(result))
  })

  test("makeError creates error response", t => {
    let error = JsonRpc.RpcError.make(
      ~code=JsonRpc.ErrorCode.methodNotFound,
      ~message="Method not found",
      ~data=None,
    )
    let resp = JsonRpc.Response.makeError(~id=2, ~error)

    t->expect(resp->JsonRpc.Response.id)->Expect.toEqual(2)
    t->expect(resp->JsonRpc.Response.isSuccess)->Expect.toEqual(false)
    t->expect(resp->JsonRpc.Response.isError)->Expect.toEqual(true)
    t->expect(resp->JsonRpc.Response.error->Option.isSome)->Expect.toEqual(true)
  })

  test("fromJsonExn parses valid response", t => {
    let json = Dict.make()
    json->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    json->Dict.set("id", JSON.Encode.int(99))
    json->Dict.set("result", JSON.Encode.string("test_result"))

    let resp = JSON.Encode.object(json)->JsonRpc.Response.fromJsonExn

    t->expect(resp->JsonRpc.Response.id)->Expect.toEqual(99)
    t->expect(resp->JsonRpc.Response.isSuccess)->Expect.toEqual(true)
  })

  test("fromJsonExn parses error response", t => {
    let errorObj = Dict.make()
    errorObj->Dict.set("code", JSON.Encode.int(-32601))
    errorObj->Dict.set("message", JSON.Encode.string("Method not found"))

    let json = Dict.make()
    json->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    json->Dict.set("id", JSON.Encode.int(5))
    json->Dict.set("error", JSON.Encode.object(errorObj))

    let resp = JSON.Encode.object(json)->JsonRpc.Response.fromJsonExn

    t->expect(resp->JsonRpc.Response.isError)->Expect.toEqual(true)
    t
    ->expect(resp->JsonRpc.Response.error->Option.map(e => e->JsonRpc.RpcError.message))
    ->Expect.toEqual(Some("Method not found"))
  })
})

describe("JsonRpc RpcError", _t => {
  test("error codes have correct integer values", t => {
    let error = JsonRpc.RpcError.make(~code=JsonRpc.ErrorCode.parseError, ~message="test", ~data=None)
    let json = error->S.reverseConvertToJsonOrThrow(JsonRpc.RpcError.schema)
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("code"))->Expect.toEqual(Some(JSON.Encode.int(-32700)))
  })

  test("all standard error codes", t => {
    let codes = [
      (JsonRpc.ErrorCode.parseError, -32700),
      (JsonRpc.ErrorCode.invalidRequest, -32600),
      (JsonRpc.ErrorCode.methodNotFound, -32601),
      (JsonRpc.ErrorCode.invalidParams, -32602),
      (JsonRpc.ErrorCode.internalError, -32603),
      (JsonRpc.ErrorCode.serverError, -32000),
    ]

    codes->Array.forEach(
      ((code, expected)) => {
        let error = JsonRpc.RpcError.make(~code, ~message="test", ~data=None)
        let json = error->S.reverseConvertToJsonOrThrow(JsonRpc.RpcError.schema)
        let obj = json->JSON.Decode.object->Option.getOrThrow
        t->expect(obj->Dict.get("code"))->Expect.toEqual(Some(JSON.Encode.int(expected)))
      },
    )
  })
})

describe("JsonRpc Notification", _t => {
  test("make creates notification without id", t => {
    let notif = JsonRpc.Notification.make(~method="initialized", ~params=None)

    t->expect(notif->JsonRpc.Notification.method)->Expect.toEqual("initialized")
    t->expect(notif->JsonRpc.Notification.params)->Expect.toEqual(None)
  })

  test("toJson produces valid structure", t => {
    let notif = JsonRpc.Notification.make(~method="test_notification", ~params=None)
    let json = notif->JsonRpc.Notification.toJson
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("jsonrpc"))->Expect.toEqual(Some(JSON.Encode.string("2.0")))
    t
    ->expect(obj->Dict.get("method"))
    ->Expect.toEqual(Some(JSON.Encode.string("test_notification")))
    t->expect(obj->Dict.get("id"))->Expect.toEqual(None)
  })
})

describe("JsonRpc version", _t => {
  test("version is 2.0", t => {
    t->expect(JsonRpc.version)->Expect.toEqual("2.0")
  })
})
