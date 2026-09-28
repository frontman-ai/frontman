type relayFailureReason = HttpError | InvalidResponse | NetworkError

type relayOutcome = Success | Failure(relayFailureReason)

type event = RelayConnectionCompleted(relayOutcome)

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
  }

let eventProperties = event => {
  let properties = frameworkProperties()
  switch event {
  | RelayConnectionCompleted(Success) =>
    properties->Dict.set("outcome", JSON.Encode.string("success"))
  | RelayConnectionCompleted(Failure(reason)) =>
    properties->Dict.set("outcome", JSON.Encode.string("failure"))
    properties->Dict.set("reason_code", JSON.Encode.string(relayFailureReasonToString(reason)))
  }
  properties
}

let track = event =>
  Client__Heap.track(eventName(event), JSON.Encode.object(eventProperties(event)))
