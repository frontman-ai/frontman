type captureOptions = {
  debug?: bool,
  fast?: bool,
  scale?: float,
  dpr?: float,
  width?: int,
  height?: int,
  backgroundColor?: string,
  quality?: float,
  useProxy?: string,
  \"type\"?: string,
  format?: string,
  exclude?: array<string>,
  filter?: (~el: WebAPI.DOMAPI.element) => bool,
  placeholders?: bool,
  embedFonts?: bool,
}

// Snapdom returns an image element with a data URL in its src
type snapshotImage = {src: string}

type captureResult = {
  url: string,
  toRaw: unit => string,
  toImg: (~options: captureOptions) => promise<snapshotImage>,
  toCanvas: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlCanvasElement>,
  toPng: (~options: captureOptions) => promise<snapshotImage>,
  toJpg: (~options: captureOptions) => promise<snapshotImage>,
  toWebp: (~options: captureOptions) => promise<snapshotImage>,
}

@module("@zumer/snapdom")
external snapdom: (~element: WebAPI.DOMAPI.element) => promise<captureResult> = "snapdom"
