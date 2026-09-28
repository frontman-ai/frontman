@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.clipboardEventInit=?,
) => UiEventsTypes.clipboardEvent = "ClipboardEvent"

include Event.Impl({type t = UiEventsTypes.clipboardEvent})
