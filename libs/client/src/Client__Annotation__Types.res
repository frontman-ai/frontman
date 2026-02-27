// Annotation types for the element annotation system
// Unified multi-select: click elements to annotate, click again to deselect.
// Comments are optional and non-blocking.

module SourceLocation = Client__Types.SourceLocation

type annotationMode =
  | Off
  | Selecting

type position = {
  xPercent: float,
  yAbsolute: float,
}

type boundingBox = {
  x: float,
  y: float,
  width: float,
  height: float,
}

type t = {
  id: string,
  element: WebAPI.DOMAPI.element, // live DOM ref (not serialized)
  comment: option<string>, // optional user comment for the annotation
  selector: option<string>, // CSS selector via @medv/finder
  screenshot: option<string>, // base64 JPEG via @zumer/snapdom
  sourceLocation: option<SourceLocation.t>,
  tagName: string,
  cssClasses: option<string>,
  boundingBox: option<boundingBox>,
  nearbyText: option<string>,
  position: position,
  timestamp: float,
}

let make = (
  ~element: WebAPI.DOMAPI.element,
  ~position: position,
  ~tagName: string,
  ~comment: option<string>=?,
): t => {
  id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
  element,
  comment,
  selector: None,
  screenshot: None,
  sourceLocation: None,
  tagName,
  cssClasses: None,
  boundingBox: None,
  nearbyText: None,
  position,
  timestamp: Date.now(),
}

// Check if an element is already annotated (by DOM reference equality)
let findByElement = (annotations: array<t>, element: WebAPI.DOMAPI.element): option<t> =>
  annotations->Array.find(a => a.element === element)
