/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationObserver)
*/
@new
external make: MutationObserverTypes.mutationObserverCallback => MutationObserverTypes.mutationObserver =
  "MutationObserver"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationObserver/observe)
*/
@send
external observe: (
  MutationObserverTypes.mutationObserver,
  ~target: DomTypes.node,
  ~options: MutationObserverTypes.mutationObserverInit=?,
) => unit = "observe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationObserver/disconnect)
*/
@send
external disconnect: MutationObserverTypes.mutationObserver => unit = "disconnect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MutationObserver/takeRecords)
*/
@send
external takeRecords: MutationObserverTypes.mutationObserver => array<DOM.mutationRecord> =
  "takeRecords"

module Types = MutationObserverTypes
