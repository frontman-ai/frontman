type captureOptions = {
  scale?: float,
  dpr?: float,
  quality?: float,
}

type snapshotImage = {src: string}

type captureResult = {
  toCanvas: captureOptions => promise<WebAPI.DOMAPI.htmlCanvasElement>,
  toJpg: captureOptions => promise<snapshotImage>,
}

@module("@zumer/snapdom")
external snapdom: WebAPI.DOMAPI.element => promise<captureResult> = "snapdom"
