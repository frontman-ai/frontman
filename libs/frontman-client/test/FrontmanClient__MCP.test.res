open Vitest

module MCP = FrontmanClient__MCP
module Types = FrontmanClient__MCP__Types
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc

// Mock channel that captures push calls
module MockChannel = {
  type pushCall = {event: string, payload: JSON.t}

  let make = () => {
    let calls: ref<array<pushCall>> = ref([])
    let channel: FrontmanClient__Phoenix__Channel.t = %raw(`{
      push: function(event, payload) {
        this._calls.push({event, payload});
        return { receive: function() { return this; } };
      },
      on: function() {},
      off: function() {},
      _calls: []
    }`)
    // Wire the ref to the raw JS array
    calls := %raw(`channel._calls`)
    (channel, calls)
  }
}

// Build a tools/call JSON-RPC request payload
let buildToolsCallPayload = (
  ~id: int,
  ~name: string,
  ~callId: string,
  ~arguments: option<JSON.t>=?,
) => {
  let params = Dict.make()
  params->Dict.set("name", JSON.Encode.string(name))
  params->Dict.set("callId", JSON.Encode.string(callId))
  switch arguments {
  | Some(args) => params->Dict.set("arguments", args)
  | None => ()
  }

  let msg = Dict.make()
  msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
  msg->Dict.set("id", JSON.Encode.int(id))
  msg->Dict.set("method", JSON.Encode.string("tools/call"))
  msg->Dict.set("params", JSON.Encode.object(params))
  JSON.Encode.object(msg)
}

// Build a mock serverInterface that returns a Completed result
let makeCompletedServerInterface = (result: Types.callToolResult) => {
  let server = ()
  let si: Types.serverInterface<unit> = {
    server,
    buildInitializeResult: _ => Obj.magic(),
    buildToolsListResult: _ => Obj.magic(),
    executeTool: async (
      _,
      ~name as _,
      ~arguments as _,
      ~taskId as _,
      ~callId as _,
      ~onProgress as _,
    ) => {
      Types.Completed(result)
    },
  }
  si
}

// Build a mock serverInterface where executeTool throws a non-S.Error exception
let makeThrowingServerInterface = (errorMsg: string) => {
  let server = ()
  let si: Types.serverInterface<unit> = {
    server,
    buildInitializeResult: _ => Obj.magic(),
    buildToolsListResult: _ => Obj.magic(),
    executeTool: async (
      _,
      ~name as _,
      ~arguments as _,
      ~taskId as _,
      ~callId as _,
      ~onProgress as _,
    ) => {
      JsError.throwWithMessage(errorMsg)
    },
  }
  si
}

// Build a JSON-RPC initialize request payload
let buildInitializePayload = (~id: int) => {
  let params = Dict.make()
  params->Dict.set("protocolVersion", JSON.Encode.string("DRAFT-2025-v3"))
  params->Dict.set("capabilities", JSON.Encode.object(Dict.make()))
  let clientInfo = Dict.make()
  clientInfo->Dict.set("name", JSON.Encode.string("test"))
  clientInfo->Dict.set("version", JSON.Encode.string("1.0"))
  params->Dict.set("clientInfo", JSON.Encode.object(clientInfo))

  let msg = Dict.make()
  msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
  msg->Dict.set("id", JSON.Encode.int(id))
  msg->Dict.set("method", JSON.Encode.string("initialize"))
  msg->Dict.set("params", JSON.Encode.object(params))
  JSON.Encode.object(msg)
}

// Build a JSON-RPC tools/list request payload
let buildToolsListPayload = (~id: int) => {
  let msg = Dict.make()
  msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
  msg->Dict.set("id", JSON.Encode.int(id))
  msg->Dict.set("method", JSON.Encode.string("tools/list"))
  JSON.Encode.object(msg)
}

// Helper: find a pushed response by JSON-RPC id
let _findResponseById = (calls: ref<array<MockChannel.pushCall>>, id: int) => {
  calls.contents->Array.find(p => {
    switch p.payload->JSON.Decode.object {
    | Some(obj) =>
      switch obj->Dict.get("id") {
      | Some(idJson) => idJson == JSON.Encode.int(id)
      | None => false
      }
    | None => false
    }
  })
}

// Helper: check if a pushed response has an "error" field
let _hasErrorField = (push: MockChannel.pushCall) => {
  switch push.payload->JSON.Decode.object {
  | Some(obj) => obj->Dict.get("error")->Option.isSome
  | None => false
  }
}

// Helper: extract the error code from a pushed error response
let _getErrorCode = (push: MockChannel.pushCall) => {
  switch push.payload->JSON.Decode.object {
  | Some(obj) =>
    switch obj->Dict.get("error") {
    | Some(errorJson) =>
      switch errorJson->JSON.Decode.object {
      | Some(errorObj) =>
        switch errorObj->Dict.get("code") {
        | Some(codeJson) => codeJson->JSON.Decode.float->Option.map(Float.toInt)
        | None => None
        }
      | None => None
      }
    | None => None
    }
  | None => None
  }
}

// Build an unknown method request payload
let _buildUnknownMethodPayload = (~id: int, ~method: string) => {
  let msg = Dict.make()
  msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
  msg->Dict.set("id", JSON.Encode.int(id))
  msg->Dict.set("method", JSON.Encode.string(method))
  JSON.Encode.object(msg)
}

describe("handleToolsCall", () => {
  testAsync("sends MCP response when tool completes successfully", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "tool output"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildToolsCallPayload(~id=42, ~name="take_screenshot", ~callId="call_1")

    await MCP.handleMessage(handler, payload)

    // Should have pushed one mcp:message response
    let pushes = calls.contents
    t->expect(pushes->Array.length >= 1)->Expect.toBe(true)

    // Find the response push
    let responsePush = pushes->Array.find(
      p => {
        switch p.payload->JSON.Decode.object {
        | Some(obj) => obj->Dict.get("id")->Option.isSome
        | None => false
        }
      },
    )

    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some({payload}) =>
      switch payload->JSON.Decode.object {
      | Some(obj) =>
        // Verify it's a success response with the correct id
        switch obj->Dict.get("id") {
        | Some(id) => t->expect(id)->Expect.toEqual(JSON.Encode.int(42))
        | None => t->expect("id")->Expect.toBe("present")
        }
        // Verify it has a result (not an error)
        t->expect(obj->Dict.get("result")->Option.isSome)->Expect.toBe(true)
      | None => t->expect("object")->Expect.toBe("parsed")
      }
    | None => t->expect("response push")->Expect.toBe("found")
    }
  })

  testAsync("sends MCP error response when tool throws S.Error", async t => {
    let (channel, calls) = MockChannel.make()

    // executeTool will receive invalid params that cause S.Error during schema parse
    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "ok"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    // Send a payload with missing required fields (no "name") to trigger S.Error
    let badPayload = {
      let msg = Dict.make()
      msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
      msg->Dict.set("id", JSON.Encode.int(99))
      msg->Dict.set("method", JSON.Encode.string("tools/call"))
      msg->Dict.set("params", JSON.Encode.object(Dict.make())) // missing name, callId
      JSON.Encode.object(msg)
    }

    await MCP.handleMessage(handler, badPayload)

    let pushes = calls.contents
    // Should have pushed an error response
    let errorPush = pushes->Array.find(
      p => {
        switch p.payload->JSON.Decode.object {
        | Some(obj) => obj->Dict.get("error")->Option.isSome
        | None => false
        }
      },
    )

    t->expect(errorPush->Option.isSome)->Expect.toBe(true)
  })

  testAsync("sends error response when executeTool throws non-S.Error exception", async t => {
    // When executeTool throws a non-S.Error (e.g., failwith from the reducer),
    // handleMessage must catch it and send back a JSON-RPC error response.
    // Before the fix, the exception escaped as an unhandled promise rejection
    // and no response was ever sent — causing the agent to hang.

    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeThrowingServerInterface(
        "[TaskReducer] QuestionReceived on Loading task",
      ),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildToolsCallPayload(~id=77, ~name="question", ~callId="call_q1")

    // handleMessage should never reject — the top-level catch guarantees this
    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 77)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) => t->expect(_hasErrorField(push))->Expect.toBe(true)
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })
})

describe("handleMessage error safety", () => {
  testAsync("sends error response when buildInitializeResult throws", async t => {
    let (channel, calls) = MockChannel.make()

    let si: Types.serverInterface<unit> = {
      server: (),
      buildInitializeResult: _ => JsError.throwWithMessage("initialize exploded"),
      buildToolsListResult: _ => Obj.magic(),
      executeTool: async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~callId as _,
        ~onProgress as _,
      ) => Obj.magic(),
    }

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: si,
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildInitializePayload(~id=10)

    // Must resolve without rejecting — the exception is caught internally
    await MCP.handleMessage(handler, payload)

    // handleInitialize catches the error and sends a JSON-RPC error response
    let responsePush = _findResponseById(calls, 10)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) => t->expect(_hasErrorField(push))->Expect.toBe(true)
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("sends error response when buildToolsListResult throws", async t => {
    let (channel, calls) = MockChannel.make()

    let si: Types.serverInterface<unit> = {
      server: (),
      buildInitializeResult: _ => Obj.magic(),
      buildToolsListResult: _ => JsError.throwWithMessage("tools list exploded"),
      executeTool: async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~callId as _,
        ~onProgress as _,
      ) => Obj.magic(),
    }

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: si,
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildToolsListPayload(~id=20)

    // Must resolve without rejecting
    await MCP.handleMessage(handler, payload)

    // handleToolsList catches the error and sends a JSON-RPC error response
    let responsePush = _findResponseById(calls, 20)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) => t->expect(_hasErrorField(push))->Expect.toBe(true)
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("does not reject when onMessage callback throws", async t => {
    let (channel, _calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "ok"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: Some((_, _) => JsError.throwWithMessage("onMessage exploded")),
    }

    let payload = buildToolsCallPayload(~id=30, ~name="test", ~callId="call_1")

    // Must resolve without rejecting
    await MCP.handleMessage(handler, payload)

    // onMessage threw before any processing happened, so no response pushed
    t->expect(true)->Expect.toBe(true)
  })
})

describe("sendError uses correct error codes", () => {
  testAsync("unknown method sends methodNotFound (-32601)", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "ok"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = _buildUnknownMethodPayload(~id=50, ~method="bogus/method")

    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 50)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.methodNotFound))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("invalid params (S.Error) sends invalidParams (-32602)", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "ok"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let badPayload = {
      let msg = Dict.make()
      msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
      msg->Dict.set("id", JSON.Encode.int(51))
      msg->Dict.set("method", JSON.Encode.string("tools/call"))
      msg->Dict.set("params", JSON.Encode.object(Dict.make()))
      JSON.Encode.object(msg)
    }

    await MCP.handleMessage(handler, badPayload)

    let responsePush = _findResponseById(calls, 51)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("missing params for tools/call sends invalidParams (-32602)", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: Types.Text, text: "ok"}],
        isError: None,
        _meta: Types.emptyMeta,
      }),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = {
      let msg = Dict.make()
      msg->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
      msg->Dict.set("id", JSON.Encode.int(52))
      msg->Dict.set("method", JSON.Encode.string("tools/call"))
      JSON.Encode.object(msg)
    }

    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 52)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.invalidParams))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("executeTool runtime exception sends serverError (-32000)", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeThrowingServerInterface("something broke"),
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildToolsCallPayload(~id=53, ~name="test_tool", ~callId="call_1")

    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 53)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.serverError))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("buildInitializeResult exception sends serverError (-32000)", async t => {
    let (channel, calls) = MockChannel.make()

    let si: Types.serverInterface<unit> = {
      server: (),
      buildInitializeResult: _ => JsError.throwWithMessage("init boom"),
      buildToolsListResult: _ => Obj.magic(),
      executeTool: async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~callId as _,
        ~onProgress as _,
      ) => Obj.magic(),
    }

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: si,
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildInitializePayload(~id=54)

    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 54)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.serverError))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })

  testAsync("buildToolsListResult exception sends serverError (-32000)", async t => {
    let (channel, calls) = MockChannel.make()

    let si: Types.serverInterface<unit> = {
      server: (),
      buildInitializeResult: _ => Obj.magic(),
      buildToolsListResult: _ => JsError.throwWithMessage("tools boom"),
      executeTool: async (
        _,
        ~name as _,
        ~arguments as _,
        ~taskId as _,
        ~callId as _,
        ~onProgress as _,
      ) => Obj.magic(),
    }

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: si,
      channel,
      sessionId: "test-task",
      onMessage: None,
    }

    let payload = buildToolsListPayload(~id=55)

    await MCP.handleMessage(handler, payload)

    let responsePush = _findResponseById(calls, 55)
    t->expect(responsePush->Option.isSome)->Expect.toBe(true)

    switch responsePush {
    | Some(push) =>
      t->expect(_getErrorCode(push))->Expect.toEqual(Some(Types.ErrorCode.serverError))
    | None => t->expect("error response")->Expect.toBe("found")
    }
  })
})
