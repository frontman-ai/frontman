/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget)
*/
@new
external make: unit => EventTypes.eventTarget = "EventTarget"

module Impl = (
  T: {
    type t
  },
) => {
  external asEventTarget: T.t => EventTypes.eventTarget = "%identity"

  /**
Appends an event listener for events whose type attribute value is type. The callback argument sets the callback that will be invoked when the event is dispatched.

The options argument sets listener-specific options. For compatibility this can be a boolean, in which case the method behaves exactly as if the value was specified as options's capture.

When set to true, options's capture prevents callback from being invoked when the event's eventPhase attribute value is BUBBLING_PHASE. When false (or not present), callback will not be invoked when event's eventPhase attribute value is CAPTURING_PHASE. Either way, callback will be invoked if event's eventPhase attribute value is AT_TARGET.

When set to true, options's passive indicates that the callback will not cancel the event by invoking preventDefault(). This is used to enable performance optimizations described in § 2.8 Observing event listeners.

When set to true, options's once indicates that the callback will only be invoked once after which the event listener will be removed.

If an AbortSignal is passed for options's signal, then the event listener will be removed when signal is aborted.

The event listener is appended to target's event listener list and is not appended if it has the same type, callback, and capture.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/addEventListener)
*/
  @send
  external addEventListener: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    ~options: EventTypes.addEventListenerOptions=?,
  ) => unit = "addEventListener"

  /**
Appends an event listener for events whose type attribute value is type. The callback argument sets the callback that will be invoked when the event is dispatched.

The options argument sets listener-specific options. For compatibility this can be a boolean, in which case the method behaves exactly as if the value was specified as options's capture.

When set to true, options's capture prevents callback from being invoked when the event's eventPhase attribute value is BUBBLING_PHASE. When false (or not present), callback will not be invoked when event's eventPhase attribute value is CAPTURING_PHASE. Either way, callback will be invoked if event's eventPhase attribute value is AT_TARGET.

When set to true, options's passive indicates that the callback will not cancel the event by invoking preventDefault(). This is used to enable performance optimizations described in § 2.8 Observing event listeners.

When set to true, options's once indicates that the callback will only be invoked once after which the event listener will be removed.

If an AbortSignal is passed for options's signal, then the event listener will be removed when signal is aborted.

The event listener is appended to target's event listener list and is not appended if it has the same type, callback, and capture.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/addEventListener)
*/
  @send
  external addEventListenerWithCapture: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    @as(json`true`) _,
  ) => unit = "addEventListener"

  /**
Removes the event listener in target's event listener list with the same type, callback, and options.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/removeEventListener)
*/
  @send
  external removeEventListener: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    ~options: EventTypes.eventListenerOptions=?,
  ) => unit = "removeEventListener"

  /**
Removes the event listener in target's event listener list with the same type, callback, and options.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/removeEventListener)
*/
  @send
  external removeEventListenerUseCapture: (
    T.t,
    EventTypes.eventType,
    EventTypes.eventListener<'event>,
    @as(json`true`) _,
  ) => unit = "removeEventListener"

  /**
Dispatches a synthetic event event to target and returns true if either event's cancelable attribute value is false or its preventDefault() method was not invoked, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventTarget/dispatchEvent)
*/
  @send
  external dispatchEvent: (T.t, EventTypes.event) => bool = "dispatchEvent"
}

include Impl({type t = EventTypes.eventTarget})
