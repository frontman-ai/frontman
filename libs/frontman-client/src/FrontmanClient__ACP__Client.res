// ACP Client - handles Agent Client Protocol communication
// Uses pure state reducer pattern

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Channel = FrontmanClient__Phoenix__Channel
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #ACP
})

type connectionState =
  | Disconnected
  | Connecting
  | Initialized(Types.initializeResult)

type pendingRequest = {
  resolve: JSON.t => unit,
  reject: string => unit,
}

type state = {
  currentId: int,
  connectionState: connectionState,
  pendingRequests: Dict.t<pendingRequest>,
}

type config = {
  channel: Channel.t,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
}

type action =
  | RequestSent(int, pendingRequest)
  | ResponseReceived(int)
  | ConnectionStateChanged(connectionState)

let initialState: state = {
  currentId: 0,
  connectionState: Disconnected,
  pendingRequests: Dict.make(),
}

// Pure reducer function
let reduce = (state: state, action: action): state => {
  switch action {
  | RequestSent(id, pending) =>
    let newPending = state.pendingRequests->Dict.copy
    newPending->Dict.set(Int.toString(id), pending)
    {
      ...state,
      currentId: id,
      pendingRequests: newPending,
    }
  | ResponseReceived(id) =>
    let newPending = state.pendingRequests->Dict.copy
    newPending->Dict.delete(Int.toString(id))
    {...state, pendingRequests: newPending}
  | ConnectionStateChanged(connectionState) => {...state, connectionState}
  }
}

// Handle incoming JSON-RPC response - returns new state
let handleResponse = (state: state, payload: JSON.t): state => {
  try {
    let response = payload->JsonRpc.Response.fromJsonExn
    let id = response->JsonRpc.Response.id
    let idStr = Int.toString(id)

    switch state.pendingRequests->Dict.get(idStr) {
    | Some({resolve, reject}) =>
      switch response->JsonRpc.Response.result {
      | Some(result) => resolve(result)
      | None =>
        switch response->JsonRpc.Response.error {
        | Some(err) => reject(err->JsonRpc.RpcError.message)
        | None => reject("Unknown error")
        }
      }
      state->reduce(ResponseReceived(id))
    | None =>
      Log.warning(`Received response for unknown request: ${idStr}`)
      state
    }
  } catch {
  | S.Error(e) =>
    Log.error(`Failed to parse JSON-RPC response: ${e.message}`)
    state
  }
}

// Build initialize params JSON
let buildInitializeParams = (config: config): JSON.t => {
  let params: Types.initializeParams = {
    protocolVersion: Types.currentProtocolVersion,
    clientCapabilities: Some(config.clientCapabilities),
    clientInfo: Some(config.clientInfo),
  }
  params->S.reverseConvertToJsonOrThrow(Types.initializeParamsSchema)
}

// Parse initialize result
let parseInitializeResult = json => json->Decoders.parseSchema(Types.initializeResultSchema)

// Parse session/new result
let parseSessionNewResult = json => json->Decoders.parseSchema(Types.sessionNewResultSchema)

// Parse session/load result
let parseSessionLoadResult = json => json->Decoders.parseSchema(Types.sessionLoadResultSchema)

// Parse session/prompt result
let parsePromptResult = json => json->Decoders.parseSchema(Types.promptResultSchema)

// Parse session/update notification
let parseSessionUpdateNotification = json =>
  json->Decoders.parseSchema(Types.sessionUpdateNotificationSchema)

// Check if initialized
let isInitialized = (state: state): bool => {
  switch state.connectionState {
  | Initialized(_) => true
  | _ => false
  }
}

// Get connection state
let getConnectionState = (state: state): connectionState => state.connectionState
