@@warning("-30")

type binaryType =
  | @as("arraybuffer") Arraybuffer
  | @as("blob") Blob

type messageEventSource = unknown

@editor.completeFrom(WebSocket)
type webSocket = {
  ...EventTypes.eventTarget,
  url: string,
  readyState: int,
  bufferedAmount: int,
  extensions: string,
  protocol: string,
  mutable binaryType: binaryType,
}

@editor.completeFrom(CloseEvent)
type closeEvent = private {
  ...EventTypes.event,
  wasClean: bool,
  code: int,
  reason: string,
}

type messageEvent<'t> = {
  ...EventTypes.event,
  data: 't,
  origin: string,
  lastEventId: string,
  source: Null.t<messageEventSource>,
  ports: array<ChannelMessagingTypes.messagePort>,
}

type closeEventInit = {
  ...EventTypes.eventInit,
  mutable wasClean?: bool,
  mutable code?: int,
  mutable reason?: string,
}

type messageEventInit<'t> = {
  ...EventTypes.eventInit,
  mutable data?: 't,
  mutable origin?: string,
  mutable lastEventId?: string,
  mutable source?: Null.t<messageEventSource>,
  mutable ports?: array<ChannelMessagingTypes.messagePort>,
}
