open EventAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event)
*/
@new
external make: (~type_: string, ~eventInitDict: eventInit=?) => event = "Event"

module Impl = (
  T: {
    type t
  },
) => {
  external asEvent: T.t => event = "%identity"

  /**
Returns the invocation target objects of event's path (objects on which listeners will be invoked), except for any nodes in shadow trees of which the shadow root's mode is "closed" that are not reachable from event's currentTarget.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/composedPath)
*/
  @send
  external composedPath: T.t => array<eventTarget> = "composedPath"

  /**
If invoked when the cancelable attribute value is true, and while executing a listener for the event with passive set to false, signals to the operation that caused event to be dispatched that it needs to be canceled.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/preventDefault)
*/
  @send
  external preventDefault: T.t => unit = "preventDefault"

  /**
Invoking this method prevents event from reaching any registered event listeners after the current one finishes running and, when dispatched in a tree, also prevents event from reaching any other objects.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/stopImmediatePropagation)
*/
  @send
  external stopImmediatePropagation: T.t => unit = "stopImmediatePropagation"

  /**
When dispatched in a tree, invoking this method prevents event from reaching any objects other than the current object.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Event/stopPropagation)
*/
  @send
  external stopPropagation: T.t => unit = "stopPropagation"
}

include Impl({type t = event})
