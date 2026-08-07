@new
external make: MutationObserverTypes.mutationObserverCallback => MutationObserverTypes.mutationObserver =
  "MutationObserver"

@send
external observe: (
  MutationObserverTypes.mutationObserver,
  ~target: DomTypes.node,
  ~options: MutationObserverTypes.mutationObserverInit=?,
) => unit = "observe"

@send
external disconnect: MutationObserverTypes.mutationObserver => unit = "disconnect"

@send
external takeRecords: MutationObserverTypes.mutationObserver => array<DOM.mutationRecord> =
  "takeRecords"

module Types = MutationObserverTypes
