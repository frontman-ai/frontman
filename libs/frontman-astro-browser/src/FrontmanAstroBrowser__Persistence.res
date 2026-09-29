let markerAttribute = "data-astro-transition-persist"
let inspectionAttributes = [markerAttribute]
let maxParentSteps = 50
let maxAncestors = 10
let maxOutputBytes = 4096

type boundaries = {
  elements: array<WebAPI.DomTypes.element>,
  truncated: bool,
}

@schema
type t = {
  @s.describe(
    "Marked DOM ancestors, nearest first, described with selectors and persistence keys. Descriptors may shorten attribute values with '...'. Follows parentElement only; does not cross shadow roots. Markers do not prove node or state survival across navigation."
  )
  @live
  ancestors: array<string>,
  @s.describe(
    "Ancestor inspection stopped at the 50-parent, 10-boundary, or 4 KB context limit. An empty truncated result does not prove there are no marked ancestors."
  )
  @live
  truncated: bool,
}

let findAncestors = (element: WebAPI.DomTypes.element): boundaries => {
  let elements = []
  let current = ref(element.parentElement->Null.toOption)
  let steps = ref(0)
  while (
    current.contents->Option.isSome &&
    steps.contents < maxParentSteps &&
    elements->Array.length < maxAncestors
  ) {
    let parent = current.contents->Option.getOrThrow->WebAPI.HTMLElement.asElement
    switch parent->WebAPI.Element.hasAttribute(markerAttribute) {
    | true => elements->Array.push(parent)->ignore
    | false => ()
    }
    steps := steps.contents + 1
    current := parent.parentElement->Null.toOption
  }
  {elements, truncated: current.contents->Option.isSome}
}

let read = (
  element: WebAPI.DomTypes.element,
  ~describeAncestor: WebAPI.DomTypes.element => string,
): t => {
  let found = findAncestors(element)
  let rec describe = (index, ancestors) => {
    switch found.elements->Array.get(index) {
    | None => {ancestors, truncated: found.truncated}
    | Some(element) =>
      let candidate = {
        ancestors: Array.concat(ancestors, [describeAncestor(element)]),
        truncated: false,
      }
      let json =
        candidate
        ->S.decodeOrThrow(~from=schema, ~to=S.json)
        ->JSON.stringifyAny
        ->Option.getOrThrow
      switch WebAPI.Blob.make(~blobParts=[String(json)]).size > maxOutputBytes {
      | true => {ancestors, truncated: true}
      | false => describe(index + 1, candidate.ancestors)
      }
    }
  }
  describe(0, [])
}
