type relayFailureReason = HttpError | InvalidResponse | NetworkError

type relayOutcome = Success | Failure(relayFailureReason)

type provider = Anthropic | OpenAI | OpenRouter | Fireworks | Nvidia | Custom
type handoffFailure = PopupBlocked | PopupClosed | AuthorizationTimedOut
type rejection = NotReady | SessionFailed | PromptFailed
type event =
  | RelayConnectionCompleted(relayOutcome)
  | EditorHandoffStarted
  | EditorHandoffCompleted
  | EditorHandoffFailed(handoffFailure)
  | EditorReady
  | ProviderConnectionStarted(provider)
  | ProviderConnectionCompleted(provider)
  | ProviderConnectionFailed(provider)
  | MessageSubmitAttempted(string)
  | MessageAccepted(string)
  | MessageRejected(string, rejection)
  | TaskRunStarted(string)
  | TaskRunCompleted(string)

let providerName = provider =>
  switch provider {
  | Anthropic => "anthropic"
  | OpenAI => "openai"
  | OpenRouter => "openrouter"
  | Fireworks => "fireworks_ai"
  | Nvidia => "nvidia"
  | Custom => "custom"
  }

let relayFailureReasonToString = reason =>
  switch reason {
  | HttpError => "http_error"
  | InvalidResponse => "invalid_response"
  | NetworkError => "network_error"
  }

let frameworkProperties = () => {
  let framework = Client__RuntimeConfig.read().framework->Client__RuntimeConfig.frameworkIdToString
  Dict.fromArray([("framework", JSON.Encode.string(framework))])
}

let eventName = event =>
  switch event {
  | RelayConnectionCompleted(_) => "relay_connection_completed"
  | EditorHandoffStarted => "editor_handoff_started"
  | EditorHandoffCompleted => "editor_handoff_completed"
  | EditorHandoffFailed(_) => "editor_handoff_failed"
  | EditorReady => "editor_ready"
  | ProviderConnectionStarted(_) => "provider_connection_started"
  | ProviderConnectionCompleted(_) => "provider_connection_completed"
  | ProviderConnectionFailed(_) => "provider_connection_failed"
  | MessageSubmitAttempted(_) => "message_submit_attempted"
  | MessageAccepted(_) => "message_accepted"
  | MessageRejected(_, _) => "message_rejected"
  | TaskRunStarted(_) => "task_run_started"
  | TaskRunCompleted(_) => "task_run_completed"
  }

let eventProperties = event => {
  let properties = frameworkProperties()
  properties->Dict.set("event_source", JSON.Encode.string("embedded_editor"))
  switch event {
  | EditorHandoffStarted | EditorHandoffCompleted | EditorReady => ()
  | EditorHandoffFailed(reason) =>
    properties->Dict.set(
      "reason_code",
      JSON.Encode.string(
        switch reason {
        | PopupBlocked => "popup_blocked"
        | PopupClosed => "popup_closed"
        | AuthorizationTimedOut => "authorization_timed_out"
        },
      ),
    )
  | ProviderConnectionStarted(provider)
  | ProviderConnectionCompleted(provider)
  | ProviderConnectionFailed(provider) =>
    properties->Dict.set("provider", JSON.Encode.string(providerName(provider)))
  | MessageSubmitAttempted(id) | MessageAccepted(id) =>
    properties->Dict.set("message_id", JSON.Encode.string(id))
  | MessageRejected(id, reason) =>
    properties->Dict.set("message_id", JSON.Encode.string(id))
    properties->Dict.set(
      "reason_code",
      JSON.Encode.string(
        switch reason {
        | NotReady => "not_ready"
        | SessionFailed => "session_failed"
        | PromptFailed => "prompt_failed"
        },
      ),
    )
  | TaskRunStarted(id) => properties->Dict.set("task_id", JSON.Encode.string(id))
  | TaskRunCompleted(id) =>
    // Idle is an observed terminal state, not proof that the task succeeded.
    properties->Dict.set("task_id", JSON.Encode.string(id))
    properties->Dict.set("outcome", JSON.Encode.string("idle"))
  | RelayConnectionCompleted(Success) =>
    properties->Dict.set("outcome", JSON.Encode.string("success"))
  | RelayConnectionCompleted(Failure(reason)) =>
    properties->Dict.set("outcome", JSON.Encode.string("failure"))
    properties->Dict.set("reason_code", JSON.Encode.string(relayFailureReasonToString(reason)))
  }
  properties
}

let track = event => {
  // Analytics is optional: blocked SDKs and browser APIs must not affect editing.
  try {
    let properties = eventProperties(event)
    properties->Dict.set(
      "event_id",
      JSON.Encode.string(WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID),
    )
    properties->Dict.set("occurred_at", JSON.Encode.string(Date.make()->Date.toISOString))
    Client__Heap.track(eventName(event), JSON.Encode.object(properties))
  } catch {
  | _ => ()
  }
}
