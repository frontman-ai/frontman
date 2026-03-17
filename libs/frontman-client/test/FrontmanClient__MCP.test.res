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
let buildToolsCallPayload = (~id: int, ~name: string, ~callId: string, ~arguments: option<JSON.t>=?) => {
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
    executeTool: async (_, ~name as _, ~arguments as _, ~taskId as _, ~callId as _, ~onProgress as _) => {
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
    executeTool: async (_, ~name as _, ~arguments as _, ~taskId as _, ~callId as _, ~onProgress as _) => {
      Exn.raiseError(errorMsg)
    },
  }
  si
}

describe("handleToolsCall", () => {
  testAsync("sends MCP response when tool completes successfully", async t => {
    let (channel, calls) = MockChannel.make()

    let handler: MCP.mcpHandler<unit> = {
      serverInterface: makeCompletedServerInterface({
        content: [{type_: "text", text: "tool output"}],
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
    let responsePush = pushes->Array.find(p => {
      switch p.payload->JSON.Decode.object {
      | Some(obj) => obj->Dict.get("id")->Option.isSome
      | None => false
      }
    })

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
        content: [{type_: "text", text: "ok"}],
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
    let errorPush = pushes->Array.find(p => {
      switch p.payload->JSON.Decode.object {
      | Some(obj) => obj->Dict.get("error")->Option.isSome
      | None => false
      }
    })

    t->expect(errorPush->Option.isSome)->Expect.toBe(true)
  })

  testAsync(
    "BUG: non-S.Error exception in executeTool silently swallows MCP response",
    async t => {
      // This test reproduces the exact bug:
      // When executeTool throws a non-S.Error (e.g., failwith from the reducer),
      // the catch block in handleToolsCall only handles S.Error.
      // The exception escapes the async function as an unhandled rejection,
      // and NO MCP response is ever sent back to the server.

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

      // This should NOT throw — the exception should be caught and an error response sent.
      // Before the fix, this would be an unhandled rejection.
      try {
        await MCP.handleMessage(handler, payload)
      } catch {
      | _ => ()
      }

      let pushes = calls.contents

      // EXPECTED: An error response should be pushed with id=77
      // BUG: Before the fix, pushes is empty — no response sent at all
      let responsePush = pushes->Array.find(p => {
        switch p.payload->JSON.Decode.object {
        | Some(obj) =>
          switch obj->Dict.get("id") {
          | Some(id) => id == JSON.Encode.int(77)
          | None => false
          }
        | None => false
        }
      })

      t
      ->expect(responsePush->Option.isSome)
      ->Expect.toBe(true)
    },
  )
})
