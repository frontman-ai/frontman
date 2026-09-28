type relayFailureReason = HttpError | InvalidResponse | NetworkError

type relayOutcome = Success | Failure(relayFailureReason)

type event =
  | RelayConnectionCompleted(relayOutcome)
  | FirstTaskFeedbackDialogShown
  | FirstTaskFeedbackDialogClosed
  | FirstTaskFeedbackShareClicked
  | FirstTaskFeedbackDiscordClicked

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
  | FirstTaskFeedbackDialogShown => "first_task_feedback_dialog_shown"
  | FirstTaskFeedbackDialogClosed => "first_task_feedback_dialog_closed"
  | FirstTaskFeedbackShareClicked => "first_task_feedback_share_clicked"
  | FirstTaskFeedbackDiscordClicked => "first_task_feedback_discord_clicked"
  }

let eventProperties = event => {
  let properties = frameworkProperties()
  switch event {
  | RelayConnectionCompleted(Success) =>
    properties->Dict.set("outcome", JSON.Encode.string("success"))
  | RelayConnectionCompleted(Failure(reason)) =>
    properties->Dict.set("outcome", JSON.Encode.string("failure"))
    properties->Dict.set("reason_code", JSON.Encode.string(relayFailureReasonToString(reason)))
  | FirstTaskFeedbackDialogShown
  | FirstTaskFeedbackDialogClosed
  | FirstTaskFeedbackShareClicked
  | FirstTaskFeedbackDiscordClicked => ()
  }
  properties
}

let track = event =>
  Client__Heap.track(eventName(event), JSON.Encode.object(eventProperties(event)))
