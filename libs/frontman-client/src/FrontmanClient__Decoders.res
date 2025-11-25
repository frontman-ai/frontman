// Simple JSON decoders

let getString = (dict, key) =>
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.string)

let getDict = (dict, key) =>
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.object)

let decodeInteraction = (json: JSON.t): result<FrontmanClient__Types.interaction, string> => {
  switch json->JSON.Decode.object {
  | None => Error("Not an object")
  | Some(dict) =>
    switch getString(dict, "type") {
    | Some("user_message") =>
      switch (
        getString(dict, "id"),
        getString(dict, "content"),
        getString(dict, "timestamp"),
      ) {
      | (Some(id), Some(content), Some(timestampStr)) =>
        Ok(
          FrontmanClient__Types.UserMessage({
            id,
            content,
            timestamp: Js.Date.fromString(timestampStr),
            metadata: getDict(dict, "metadata")->Option.getOr(Dict.make()),
          }),
        )
      | _ => Error("Missing required fields for user_message")
      }
    | Some("agent_response") =>
      switch (
        getString(dict, "id"),
        getString(dict, "agent_id"),
        getString(dict, "content"),
        getString(dict, "timestamp"),
      ) {
      | (Some(id), Some(agentId), Some(content), Some(timestampStr)) =>
        Ok(
          FrontmanClient__Types.AgentResponse({
            id,
            agentId,
            content,
            timestamp: Js.Date.fromString(timestampStr),
            metadata: getDict(dict, "metadata")->Option.getOr(Dict.make()),
          }),
        )
      | _ => Error("Missing required fields for agent_response")
      }
    | Some("agent_spawned") =>
      switch (getString(dict, "id"), getString(dict, "agent_id"), getString(dict, "timestamp")) {
      | (Some(id), Some(agentId), Some(timestampStr)) =>
        Ok(
          FrontmanClient__Types.AgentSpawned({
            id,
            agentId,
            config: getDict(dict, "config")->Option.getOr(Dict.make()),
            timestamp: Js.Date.fromString(timestampStr),
          }),
        )
      | _ => Error("Missing required fields for agent_spawned")
      }
    | Some("agent_completed") =>
      switch (getString(dict, "id"), getString(dict, "agent_id"), getString(dict, "timestamp")) {
      | (Some(id), Some(agentId), Some(timestampStr)) =>
        Ok(
          FrontmanClient__Types.AgentCompleted({
            id,
            agentId,
            timestamp: Js.Date.fromString(timestampStr),
            result: dict->Dict.get("result"),
          }),
        )
      | _ => Error("Missing required fields for agent_completed")
      }
    | _ => Error("Unknown interaction type")
    }
  }
}

let decodeStreamToken = (json: JSON.t): result<FrontmanClient__Types.streamToken, string> => {
  switch json->JSON.Decode.object {
  | None => Error("Not an object")
  | Some(dict) =>
    switch (getString(dict, "agent_id"), getString(dict, "token")) {
    | (Some(agentId), Some(token)) => Ok({agentId, token})
    | _ => Error("Missing required fields for stream_token")
    }
  }
}
