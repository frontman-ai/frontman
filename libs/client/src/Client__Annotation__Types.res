module SourceLocation = Client__Types.SourceLocation

type annotationMode =
  | Off
  | Selecting
  | TextEditing

type boundingBox = {
  x: float,
  y: float,
  width: float,
  height: float,
}

type enrichmentStatus =
  | Enriching
  | Enriched
  | Failed({error: string})

type t = {
  id: string,
  element: WebAPI.DomTypes.element,
  comment: option<string>,
  selector: result<option<string>, string>,
  elementContext: result<option<string>, string>,
  screenshot: result<option<string>, string>,
  sourceLocation: result<option<SourceLocation.t>, string>,
  tagName: string,
  cssClasses: option<string>,
  boundingBox: option<boundingBox>,
  nearbyText: option<string>,
  elementorContext: option<Client__ElementorDetection.t>,
  enrichmentStatus: enrichmentStatus,
}

let make = (~element: WebAPI.DomTypes.element, ~tagName: string): t => {
  id: WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
  element,
  comment: None,
  selector: Ok(None),
  elementContext: Ok(None),
  screenshot: Ok(None),
  sourceLocation: Ok(None),
  tagName,
  cssClasses: None,
  boundingBox: None,
  nearbyText: None,
  elementorContext: None,
  enrichmentStatus: Enriching,
}

let findByElement = (annotations: array<t>, element: WebAPI.DomTypes.element): option<t> =>
  annotations->Array.find(a => a.element === element)
