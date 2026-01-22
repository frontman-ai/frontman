// Task handle with lazy creation and message sending

type channelMessage =
  | Interaction(FrontmanClient__Types.interaction)
  | StreamToken(FrontmanClient__Types.streamToken)
  | AgentCompleted
  | AgentError(string)
  | DecodeError(string)

type state = {
  taskId: ref<option<string>>,
  channel: ref<option<FrontmanClient__Phoenix__Channel.t>>,
  interactions: ref<array<FrontmanClient__Types.interaction>>,
  isStreaming: ref<bool>,
  streamingContent: ref<string>,
}

type t = {
  connection: FrontmanClient__Connection.t,
  state: state,
  onStreamToken: option<FrontmanClient__Types.onStreamToken>,
  onInteraction: option<FrontmanClient__Types.onInteraction>,
  onFinish: option<FrontmanClient__Types.onFinish>,
  onError: option<FrontmanClient__Types.onError>,
}

let make = (
  ~connection: FrontmanClient__Connection.t,
  ~onStreamToken: option<FrontmanClient__Types.onStreamToken>=?,
  ~onInteraction: option<FrontmanClient__Types.onInteraction>=?,
  ~onFinish: option<FrontmanClient__Types.onFinish>=?,
  ~onError: option<FrontmanClient__Types.onError>=?,
  (),
): t => {
  {
    connection,
    state: {
      taskId: ref(None),
      channel: ref(None),
      interactions: ref([]),
      isStreaming: ref(false),
      streamingContent: ref(""),
    },
    onStreamToken,
    onInteraction,
    onFinish,
    onError,
  }
}

let getInteractions = (t: t): array<FrontmanClient__Types.interaction> =>
  t.state.interactions.contents

let isStreaming = (t: t): bool => t.state.isStreaming.contents

let getTaskId = (t: t): option<string> => t.state.taskId.contents

// Internal handler for all channel messages
let handleChannelMessage = (t: t, message: channelMessage): unit => {
  switch message {
  | Interaction(interaction) => {
      // Add to interactions array
      t.state.interactions := Array.concat(t.state.interactions.contents, [interaction])
      // Call callback
      t.onInteraction->Option.forEach(cb => cb(interaction))
    }
  | StreamToken(streamToken) => {
      // Accumulate in streamingContent
      t.state.streamingContent := t.state.streamingContent.contents ++ streamToken.token
      t.state.isStreaming := true
      // Call onStreamToken callback
      t.onStreamToken->Option.forEach(cb => cb(streamToken))
    }
  | AgentCompleted => {
      t.state.isStreaming := false
      t.onFinish->Option.forEach(cb => cb(~usage=None))
    }
  | AgentError(error) => {
      t.state.isStreaming := false
      t.onError->Option.forEach(cb => cb(error))
    }
  | DecodeError(error) => t.onError->Option.forEach(cb => cb(error))
  }
}

// Internal helper to setup channel listeners
let setupChannelListeners = (t: t, channel: FrontmanClient__Phoenix__Channel.t): unit => {
  channel->FrontmanClient__Phoenix__Channel.on(~event=#interaction, ~callback=payload => {
    let message = switch FrontmanClient__Decoders.decodeInteraction(payload) {
    | Ok(interaction) => Interaction(interaction)
    | Error(msg) => DecodeError(msg)
    }
    handleChannelMessage(t, message)
  })

  channel->FrontmanClient__Phoenix__Channel.on(~event=#stream_token, ~callback=payload => {
    let message = switch FrontmanClient__Decoders.decodeStreamToken(payload) {
    | Ok(streamToken) => StreamToken(streamToken)
    | Error(msg) => DecodeError(msg)
    }
    handleChannelMessage(t, message)
  })

  channel->FrontmanClient__Phoenix__Channel.on(~event=#agent_completed, ~callback=_payload => {
    handleChannelMessage(t, AgentCompleted)
  })

  channel->FrontmanClient__Phoenix__Channel.on(~event=#agent_error, ~callback=payload => {
    let message = switch payload->JSON.Decode.object {
    | Some(dict) =>
      switch dict->Dict.get("message")->Option.flatMap(JSON.Decode.string) {
      | Some(msg) => msg
      | None => "Unknown agent error"
      }
    | None => "Malformed agent error payload"
    }
    handleChannelMessage(t, AgentError(message))
  })
}

// Internal function to join channel (called on first message)
let joinChannel = (t: t, message: string): promise<FrontmanClient__Types.result<unit, string>> => {
  Promise.make((resolve, _reject) => {
    let socket = t.connection->FrontmanClient__Connection.getSocket

    // Create params with message
    let params = Dict.make()
    params->Dict.set("message", JSON.Encode.string(message))

    // Create channel for "task:new"
    let channel = socket->FrontmanClient__Phoenix__Socket.channel(~topic="task:new", ~params)

    // Setup listeners before joining
    setupChannelListeners(t, channel)

    // Join channel
    let pushRef = channel->FrontmanClient__Phoenix__Channel.join

    pushRef.receive(~status="ok", ~callback=response => {
      // Extract task_id from response
      switch response->JSON.Decode.object {
      | Some(dict) =>
        switch dict->Dict.get("task_id")->Option.flatMap(JSON.Decode.string) {
        | Some(taskId) => {
            // Update state with taskId and channel
            t.state.taskId := Some(taskId)
            t.state.channel := Some(channel)
            resolve(FrontmanClient__Types.Ok())
          }
        | None => resolve(FrontmanClient__Types.Error("No task_id in response"))
        }
      | None => resolve(FrontmanClient__Types.Error("Invalid response format"))
      }
    }).receive(~status="error", ~callback=_error => {
      resolve(FrontmanClient__Types.Error("Failed to join channel"))
    })->ignore
  })
}

// Send a message (joins channel on first call, pushes on subsequent calls)
let sendMessage = (t: t, message: string): promise<FrontmanClient__Types.result<unit, string>> => {
  switch t.state.channel.contents {
  | None => joinChannel(t, message)
  | Some(channel) =>
    Promise.make((resolve, _reject) => {
      let payloadDict = Dict.make()
      payloadDict->Dict.set("content", JSON.Encode.string(message))
      let payload = payloadDict->JSON.Encode.object

      let pushRef = channel->FrontmanClient__Phoenix__Channel.push(~event=#send_message, ~payload)

      pushRef.receive(~status="ok", ~callback=_response => {
        resolve(FrontmanClient__Types.Ok())
      }).receive(~status="error", ~callback=_error => {
        resolve(FrontmanClient__Types.Error("Failed to send message"))
      })->ignore
    })
  }
}
