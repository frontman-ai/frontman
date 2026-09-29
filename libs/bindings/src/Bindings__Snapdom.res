type clip = {x: float, y: float, width: float, height: float}

type captureOptions = {
  clip?: clip,
  reconcile?: bool,
  scale?: float,
  dpr?: float,
  quality?: float,
}

type snapshotImage = {src: string}

type captureResult = {
  toCanvas: captureOptions => promise<WebAPI.DomTypes.htmlCanvasElement>,
  toJpg: captureOptions => promise<snapshotImage>,
}

@module("@zumer/snapdom")
external snapdom: (WebAPI.DomTypes.element, ~options: captureOptions=?) => promise<captureResult> =
  "snapdom"
