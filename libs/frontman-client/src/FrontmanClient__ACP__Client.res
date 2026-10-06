module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Decoders = FrontmanClient__Decoders
type acpState =
  | Disconnected
  | Connecting
  | Initialized(Types.initializeResult)

type requestError = {
  code: option<int>,
  message: string,
}

type state = {
  currentId: int,
  acpState: acpState,
  agentAttributionConfiguration: option<Types.agentAttributionConfigurationMetadata>,
}

@@live
type config = {
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
}

type action = ACPStateChanged(acpState)

let initialState: state = {
  currentId: 0,
  acpState: Disconnected,
  agentAttributionConfiguration: None,
}

let requestErrorFromMessage = message => {code: None, message}
let requestErrorWithCode = (~code, ~message) => {code: Some(code), message}
let requestErrorMessage = error => error.message
let requestErrorCode = error => error.code
let requestErrorIsBillingInactive = error => error.code == Some(JsonRpc.ErrorCode.billingInactive)

let parseAgentAttributionConfiguration = (result: Types.initializeResult) => {
  switch result.agentCapabilities->Option.flatMap(capabilities => capabilities._meta) {
  | None => Ok(None)
  | Some(metadata) =>
    switch metadata->Decoders.parseSchema(Types.capabilityMetadataSchema) {
    | Error(error) => Error(error)
    | Ok(metadata) =>
      let advertisedVersion =
        metadata.frontmanDev
        ->Option.flatMap(frontman => frontman.agentAttribution)
        ->Option.map(attribution => attribution.version)
      switch advertisedVersion {
      | Some(1) => {
          let configuration =
            result.agentCapabilities
            ->Option.flatMap(capabilities => capabilities._meta)
            ->Option.flatMap(JSON.Decode.object)
            ->Option.flatMap(metadata => metadata->Dict.get("frontman.dev"))
          switch configuration {
          | None => Error("Initialize response missing frontman.dev configuration")
          | Some(configuration) =>
            configuration
            ->Decoders.parseSchema(Types.agentAttributionConfigurationMetadataSchema)
            ->Result.map(configuration => Some(configuration))
          }
        }
      | _ => Ok(None)
      }
    }
  }
}

let reduce = (state: state, action: action): state => {
  switch action {
  | ACPStateChanged(Initialized(result) as acpState) => {
      ...state,
      acpState,
      agentAttributionConfiguration: result
      ->parseAgentAttributionConfiguration
      ->Result.getOrThrow,
    }
  | ACPStateChanged(acpState) => {...state, acpState, agentAttributionConfiguration: None}
  }
}

let advertiseAgentAttribution = metadata => {
  let merged =
    metadata->Option.mapOr(Dict.make(), metadata =>
      metadata->JSON.Decode.object->Option.getOrThrow->Dict.copy
    )
  let frontman =
    merged
    ->Dict.get("frontman.dev")
    ->Option.mapOr(Dict.make(), value => value->JSON.Decode.object->Option.getOrThrow->Dict.copy)
  let advertisement =
    ({version: 1}: Types.agentAttributionCapability)->S.decodeOrThrow(
      ~from=Types.agentAttributionCapabilitySchema,
      ~to=S.json->S.noValidation(true),
    )
  frontman->Dict.set("agentAttribution", advertisement)
  merged->Dict.set("frontman.dev", JSON.Encode.object(frontman))
  JSON.Encode.object(merged)
}

let buildInitializeParams = (config: config): JSON.t => {
  let params: Types.initializeParams = {
    protocolVersion: Types.currentProtocolVersion,
    clientCapabilities: Some({
      ...config.clientCapabilities,
      _meta: Some(advertiseAgentAttribution(config.clientCapabilities._meta)),
    }),
    clientInfo: Some(config.clientInfo),
  }
  params->Types.initializeParamsToJson
}

let ensureSupportedProtocolVersion = ({protocolVersion} as result: Types.initializeResult) => {
  switch protocolVersion == Types.currentProtocolVersion {
  | true => Ok(result)
  | false => Error(`Unsupported ACP protocol version: ${protocolVersion->Int.toString}`)
  }
}

let parseInitializeResult = json =>
  json
  ->Decoders.parseSchema(Types.initializeResultSchema)
  ->Result.flatMap(ensureSupportedProtocolVersion)
  ->Result.flatMap(result =>
    result->parseAgentAttributionConfiguration->Result.map(_configuration => result)
  )

let parseSessionNewResult = json => json->Decoders.parseSchema(Types.sessionNewResultSchema)

let parseSessionLoadResult = json => json->Decoders.parseSchema(Types.sessionLoadResultSchema)

let parsePromptResult = json => json->Decoders.parseSchema(Types.promptResultSchema)

let sessionUpdateName = json =>
  json
  ->JSON.Decode.object
  ->Option.flatMap(message => message->Dict.get("params"))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(params => params->Dict.get("update"))
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(update => update->Dict.get("sessionUpdate"))
  ->Option.flatMap(JSON.Decode.string)

let knownSessionUpdate = name =>
  switch name {
  | "agent_message_chunk"
  | "user_message_chunk"
  | "message_unqueued"
  | "tool_call"
  | "tool_call_update"
  | "plan"
  | "config_option_update"
  | "current_mode_update"
  | "state_update"
  | "error" => true
  | _ => false
  }

let parseSessionUpdateNotification = (state, json) => {
  let schema = switch (state.agentAttributionConfiguration, sessionUpdateName(json)) {
  | (Some(_), Some(name)) if knownSessionUpdate(name) => Types.sessionUpdateNotificationSchema
  | (None, Some(name)) if knownSessionUpdate(name) => Types.genericSessionUpdateNotificationSchema
  | (_, Some(_unknown)) => Types.unknownSessionUpdateNotificationSchema
  | (_, None) => Types.genericSessionUpdateNotificationSchema
  }
  json->Decoders.parseSchema(schema)
}

let isInitialized = (state: state): bool => {
  switch state.acpState {
  | Initialized(_) => true
  | _ => false
  }
}

let getACPState = (state: state): acpState => state.acpState

type messageRole = Assistant | User

type messageIdentity = {
  role: messageRole,
  agentId: string,
  timestamp: string,
}

let makeSessionUpdateValidator = (state: state, ~sessionId: string) => {
  let identities: Dict.t<messageIdentity> = Dict.make()
  let agentIds =
    state.agentAttributionConfiguration->Option.map(configuration =>
      configuration.agents->Array.map(agent => agent.id)->Set.fromArray
    )

  (notificationSessionId, update) => {
    switch notificationSessionId == sessionId {
    | false => Error(`Session update ${notificationSessionId} received on ${sessionId}`)
    | true =>
      let identity = switch (state.agentAttributionConfiguration, update) {
      | (Some(_), Types.AgentMessageChunk({messageId, _meta: {agentId, timestamp}})) =>
        Some((messageId, {role: Assistant, agentId, timestamp}))
      | (Some(_), Types.UserMessageChunk({messageId, _meta: {agentId, timestamp}})) =>
        Some((messageId, {role: User, agentId, timestamp}))
      | _ => None
      }

      switch identity {
      | Some((_, {agentId}))
        if !(
          agentIds
          ->Option.getOrThrow(~message="Validated v1 connection configuration is required")
          ->Set.has(agentId)
        ) =>
        Error(`Session update references unknown agent: ${agentId}`)
      | Some((messageId, identity)) =>
        switch identities->Dict.get(messageId) {
        | Some(existing) if existing.role != identity.role =>
          Error(`Message ${messageId} changed roles`)
        | Some(existing) if existing.agentId != identity.agentId =>
          Error(`Message ${messageId} changed agents`)
        | Some(existing) if existing.timestamp != identity.timestamp =>
          Error(`Message ${messageId} changed timestamps`)
        | Some(_) => Ok()
        | None =>
          identities->Dict.set(messageId, identity)
          Ok()
        }
      | None => Ok()
      }
    }
  }
}
