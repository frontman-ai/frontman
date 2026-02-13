// Annotation types for the element annotation system
// Replaces SelectedElement with a richer annotation model that supports
// both quick single-click and batch multi-annotation workflows

module SourceLocation = Client__Types.SourceLocation

type annotationMode =
  | Off
  | Quick
  | Batch

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
  comment: option<string>, // optional in Quick mode, required in Batch
  selector: option<string>, // CSS selector via @medv/finder
  screenshot: option<string>, // base64 JPEG via @zumer/snapdom
  sourceLocation: option<SourceLocation.t>,
  tagName: string,
  cssClasses: option<string>,
  boundingBox: option<boundingBox>,
  nearbyText: option<string>,
  position: position,
  timestamp: float,
  selectedText: option<string>,
}

// Pending annotation: element clicked, awaiting enrichment or comment
type pending = {
  element: WebAPI.DOMAPI.element,
  position: position,
  tagName: string,
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
  selectedText: None,
}

// Get the first annotation from an array (for Quick mode compatibility)
let first = (annotations: array<t>): option<t> =>
  annotations->Array.get(0)
