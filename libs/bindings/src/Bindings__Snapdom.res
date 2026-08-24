type captureOptions = {
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
external snapdom: WebAPI.DomTypes.element => promise<captureResult> = "snapdom"
