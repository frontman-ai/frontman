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

@module
external exports: {"snapdom": WebAPI.DomTypes.element => promise<captureResult>} = "@zumer/snapdom"

@module("@zumer/snapdom")
external snapdom: WebAPI.DomTypes.element => promise<captureResult> = "snapdom"
