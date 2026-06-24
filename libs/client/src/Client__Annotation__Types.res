// Annotation types for the element annotation system
// Unified multi-select: click elements to annotate, click again to deselect.
// Comments are optional and non-blocking.

module SourceLocation = Client__Types.SourceLocation

type annotationMode =
  | Off
  | Selecting
  | Drawing

type viewportPoint = ViewportPoint({x: float, y: float})
type documentPoint = DocumentPoint({x: float, y: float})
type localPoint = LocalPoint({x: float, y: float})

type viewportBoundingBox = ViewportBoundingBox({x: float, y: float, width: float, height: float})
type documentBoundingBox = DocumentBoundingBox({x: float, y: float, width: float, height: float})

let viewportPoint = (~x: float, ~y: float): viewportPoint => ViewportPoint({x, y})

let viewportBoundingBox = (
  ~x: float,
  ~y: float,
  ~width: float,
  ~height: float,
): viewportBoundingBox => ViewportBoundingBox({x, y, width, height})

let documentBoundingBox = (
  ~x: float,
  ~y: float,
  ~width: float,
  ~height: float,
): documentBoundingBox => DocumentBoundingBox({x, y, width, height})

let viewportPointToDocument = (
  ViewportPoint(point): viewportPoint,
  ~scrollX: float,
  ~scrollY: float,
): documentPoint => DocumentPoint({x: point.x +. scrollX, y: point.y +. scrollY})

let viewportPointToLocal = (ViewportPoint(point): viewportPoint): localPoint => LocalPoint({
  x: point.x,
  y: point.y,
})

let documentBoundingBoxToViewport = (
  DocumentBoundingBox(box): documentBoundingBox,
  ~scrollX: float,
  ~scrollY: float,
): viewportBoundingBox => ViewportBoundingBox({
  x: box.x -. scrollX,
  y: box.y -. scrollY,
  width: box.width,
  height: box.height,
})

let localPointsFromDocument = (
  points: array<documentPoint>,
  DocumentBoundingBox(box): documentBoundingBox,
): array<localPoint> =>
  points->Array.map((DocumentPoint(point): documentPoint) => LocalPoint({
    x: point.x -. box.x,
    y: point.y -. box.y,
  }))

type penShape = {
  documentPoints: array<documentPoint>,
  documentBoundingBox: documentBoundingBox,
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
  boundingBox: option<viewportBoundingBox>,
  penShape: option<penShape>,
  nearbyText: option<string>,
  elementorContext: option<Client__ElementorDetection.t>,
  enrichmentStatus: enrichmentStatus,
}

let make = (~element: WebAPI.DOMAPI.element, ~tagName: string): t => {
  id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
  element,
  comment: None,
  selector: Ok(None),
  screenshot: Ok(None),
  sourceLocation: Ok(None),
  tagName,
  cssClasses: None,
  boundingBox: None,
  penShape: None,
  nearbyText: None,
  elementorContext: None,
  enrichmentStatus: Enriching,
}

let makePenShape = (
  ~element: WebAPI.DOMAPI.element,
  ~tagName: string,
  ~documentPoints: array<documentPoint>,
  ~documentBoundingBox: documentBoundingBox,
): t => {
  ...make(~element, ~tagName),
  penShape: Some({documentPoints, documentBoundingBox}),
}

// Check if an element is already annotated (by DOM reference equality)
let findByElement = (annotations: array<t>, element: WebAPI.DOMAPI.element): option<t> =>
  annotations->Array.find(a => a.element === element)
