/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: UiEventsTypes.clipboardEventInit=?,
) => UiEventsTypes.clipboardEvent = "ClipboardEvent"

include Event.Impl({type t = UiEventsTypes.clipboardEvent})
