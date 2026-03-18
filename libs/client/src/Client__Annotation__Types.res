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

// Enrichment lifecycle status — tracks the async FetchAnnotationDetails effect
type enrichmentStatus =
  | Enriching // promises still in-flight
  | Enriched // all promises resolved (individual fields may still be Error)
  | Failed({error: string}) // outer promise chain threw — total failure

type t = {
  id: string,
  element: WebAPI.DOMAPI.element, // live DOM ref (not serialized)
  comment: option<string>, // optional user comment for the annotation
  // Async enrichment fields — result captures per-field success/failure
  selector: result<option<string>, string>, // CSS selector via @medv/finder
  screenshot: result<option<string>, string>, // base64 JPEG via @zumer/snapdom
  sourceLocation: result<option<SourceLocation.t>, string>,
  tagName: string,
  // Sync enrichment fields — extracted from DOM, cannot fail
  cssClasses: option<string>,
  boundingBox: option<boundingBox>,
  nearbyText: option<string>,
  position: position,
  timestamp: float,
  enrichmentStatus: enrichmentStatus,
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
  selector: Ok(None),
  screenshot: Ok(None),
  sourceLocation: Ok(None),
  tagName,
  cssClasses: None,
  boundingBox: None,
  nearbyText: None,
  position,
  timestamp: Date.now(),
  enrichmentStatus: Enriching,
}

// Check if an element is already annotated (by DOM reference equality)
let findByElement = (annotations: array<t>, element: WebAPI.DOMAPI.element): option<t> =>
  annotations->Array.find(a => a.element === element)
