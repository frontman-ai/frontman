@@warning("-30")

/**
This Channel Messaging API interface represents one of the two ports of a MessageChannel, allowing messages to be sent from one port and listening out for them arriving at the other.
[See MessagePort on MDN](https://developer.mozilla.org/docs/Web/API/MessagePort)
*/
@editor.completeFrom(MessagePort)
type messagePort = private {
  ...EventTypes.eventTarget,
}

type structuredSerializeOptions = {mutable transfer?: array<Dict.t<string>>}
