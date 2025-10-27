open EventAPI
open WebSocketsAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: messageEventInit<'t>=?) => messageEvent<'t> =
  "MessageEvent"

external asEvent: messageEvent<'t> => event = "%identity"

@send
external asMessageEvent: event => messageEvent<'t> = "%identity"
/**
Returns the invocation target objects of event's path (objects on which listeners will be invoked), except for any nodes in shadow trees of which the shadow root's mode is "closed" that are not reachable from event's currentTarget.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/composedPath)
*/
@send
external composedPath: messageEvent<'t> => array<eventTarget> = "composedPath"
/**
The data sent by the message emitter.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/data)
*/
@get
external data: messageEvent<'t> => {..} = "data"

/**
When dispatched in a tree, invoking this method prevents event from reaching any objects other than the current object.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/stopPropagation)
*/
@send
external stopPropagation: messageEvent<'t> => unit = "stopPropagation"

/**
Invoking this method prevents event from reaching any registered event listeners after the current one finishes running and, when dispatched in a tree, also prevents event from reaching any other objects.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/stopImmediatePropagation)
*/
@send
external stopImmediatePropagation: messageEvent<'t> => unit = "stopImmediatePropagation"

/**
If invoked when the cancelable attribute value is true, and while executing a listener for the event with passive set to false, signals to the operation that caused event to be dispatched that it needs to be canceled.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/preventDefault)
*/
@send
external preventDefault: messageEvent<'t> => unit = "preventDefault"
