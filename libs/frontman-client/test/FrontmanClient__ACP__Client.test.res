open Vitest

module Client = FrontmanClient__ACP__Client
module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc

describe("ACP Client State Reducer", _t => {
  test("initialState has correct defaults", t => {
    let state = Client.initialState

    t->expect(state.currentId)->Expect.toEqual(0)
    t->expect(state.connectionState)->Expect.toEqual(Client.Disconnected)
    t->expect(state.pendingRequests->Dict.keysToArray->Array.length)->Expect.toEqual(0)
  })

  test("RequestSent action updates currentId and pendingRequests", t => {
    let state = Client.initialState
    let pending: Client.pendingRequest = {
      resolve: _ => (),
      reject: _ => (),
    }

    let newState = state->Client.reduce(Client.RequestSent(1, pending))

    t->expect(newState.currentId)->Expect.toEqual(1)
    t->expect(newState.pendingRequests->Dict.get("1")->Option.isSome)->Expect.toEqual(true)
  })

  test("ResponseReceived action removes from pendingRequests", t => {
    let pending: Client.pendingRequest = {
      resolve: _ => (),
      reject: _ => (),
    }

    let state =
      Client.initialState
      ->Client.reduce(Client.RequestSent(1, pending))
      ->Client.reduce(Client.ResponseReceived(1))

    t->expect(state.pendingRequests->Dict.get("1"))->Expect.toEqual(None)
  })

  test("ConnectionStateChanged action updates connectionState", t => {
    let state = Client.initialState
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: None,
      agentInfo: Some({name: "test", version: "1.0", title: None, _meta: None}),
      authMethods: None,
    }

    let newState =
      state->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(initResult)))

    t->expect(Client.isInitialized(newState))->Expect.toEqual(true)
  })

  test("multiple RequestSent actions accumulate", t => {
    let pending1: Client.pendingRequest = {resolve: _ => (), reject: _ => ()}
    let pending2: Client.pendingRequest = {resolve: _ => (), reject: _ => ()}

    let state =
      Client.initialState
      ->Client.reduce(Client.RequestSent(1, pending1))
      ->Client.reduce(Client.RequestSent(2, pending2))

    t->expect(state.currentId)->Expect.toEqual(2)
    t->expect(state.pendingRequests->Dict.keysToArray->Array.length)->Expect.toEqual(2)
  })
})

describe("ACP Client Connection State", _t => {
  test("isInitialized returns false for Disconnected", t => {
    let state = {...Client.initialState, connectionState: Client.Disconnected}
    t->expect(Client.isInitialized(state))->Expect.toEqual(false)
  })

  test("isInitialized returns false for Connecting", t => {
    let state = {...Client.initialState, connectionState: Client.Connecting}
    t->expect(Client.isInitialized(state))->Expect.toEqual(false)
  })

  test("isInitialized returns true for Initialized", t => {
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: None,
      agentInfo: None,
      authMethods: None,
    }
    let state = {...Client.initialState, connectionState: Client.Initialized(initResult)}
    t->expect(Client.isInitialized(state))->Expect.toEqual(true)
  })

  test("getConnectionState returns current state", t => {
    let state = {...Client.initialState, connectionState: Client.Connecting}
    t->expect(Client.getConnectionState(state))->Expect.toEqual(Client.Connecting)
  })
})

describe("ACP Client buildInitializeParams", _t => {
  test("builds correct JSON structure", t => {
    let mockChannel = %raw(`{push: () => {}, on: () => {}}`)

    let config: Client.config = {
      channel: mockChannel,
      clientInfo: {name: "test-client", version: "1.0.0", title: None, _meta: None},
      clientCapabilities: {
        fs: Some({readTextFile: Some(true), writeTextFile: Some(false)}),
        terminal: Some(true),
        elicitation: None,
      },
    }

    let json = Client.buildInitializeParams(config)
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("protocolVersion"))->Expect.toEqual(Some(JSON.Encode.int(1)))

    let clientInfoJson = obj->Dict.get("clientInfo")->Option.flatMap(JSON.Decode.object)
    t
    ->expect(clientInfoJson->Option.flatMap(c => c->Dict.get("name")))
    ->Expect.toEqual(Some(JSON.Encode.string("test-client")))
  })
})

describe("ACP Client parseInitializeResult", _t => {
  test("parses valid result", t => {
    let json = Dict.make()
    json->Dict.set("protocolVersion", JSON.Encode.int(1))

    let result = Client.parseInitializeResult(JSON.Encode.object(json))

    switch result {
    | Ok(parsed) => t->expect(parsed.protocolVersion)->Expect.toEqual(1)
    | Error(_) => failwith("Expected Ok result")
    }
  })

  test("returns error for invalid JSON", t => {
    let result = Client.parseInitializeResult(JSON.Encode.string("invalid"))

    t->expect(Result.isError(result))->Expect.toEqual(true)
  })
})

describe("ACP Client handleResponse", _t => {
  test("resolves pending request on success", t => {
    let resolved = ref(false)
    let pending: Client.pendingRequest = {
      resolve: _ => resolved := true,
      reject: _ => (),
    }

    let state = Client.initialState->Client.reduce(Client.RequestSent(1, pending))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(1))
    responseJson->Dict.set("result", JSON.Encode.string("success"))

    let _newState = Client.handleResponse(state, JSON.Encode.object(responseJson))

    t->expect(resolved.contents)->Expect.toEqual(true)
  })

  test("rejects pending request on error", t => {
    let rejected = ref(false)
    let pending: Client.pendingRequest = {
      resolve: _ => (),
      reject: _ => rejected := true,
    }

    let state = Client.initialState->Client.reduce(Client.RequestSent(2, pending))

    let errorObj = Dict.make()
    errorObj->Dict.set("code", JSON.Encode.int(-32600))
    errorObj->Dict.set("message", JSON.Encode.string("Invalid request"))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(2))
    responseJson->Dict.set("error", JSON.Encode.object(errorObj))

    let _newState = Client.handleResponse(state, JSON.Encode.object(responseJson))

    t->expect(rejected.contents)->Expect.toEqual(true)
  })

  test("removes request from pending after handling", t => {
    let pending: Client.pendingRequest = {resolve: _ => (), reject: _ => ()}

    let state = Client.initialState->Client.reduce(Client.RequestSent(3, pending))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(3))
    responseJson->Dict.set("result", JSON.Encode.null)

    let newState = Client.handleResponse(state, JSON.Encode.object(responseJson))

    t->expect(newState.pendingRequests->Dict.get("3"))->Expect.toEqual(None)
  })
})
