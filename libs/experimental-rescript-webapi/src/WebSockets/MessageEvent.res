type event = EventTypes.event
type eventTarget = EventTypes.eventTarget
type messageEventSource = WebSocketsTypes.messageEventSource

type messageEvent<'t> = WebSocketsTypes.messageEvent<'t>
type messageEventInit<'t> = WebSocketsTypes.messageEventInit<'t>

type t<'t> = messageEvent<'t>

@new
external make: (~type_: string, ~eventInitDict: messageEventInit<'t>=?) => t<'t> = "MessageEvent"

external asEvent: t<'t> => event = "%identity"
@send
external composedPath: t<'t> => array<eventTarget> = "composedPath"

@send
external stopPropagation: t<'t> => unit = "stopPropagation"

@send
external stopImmediatePropagation: t<'t> => unit = "stopImmediatePropagation"

@send
external preventDefault: t<'t> => unit = "preventDefault"
