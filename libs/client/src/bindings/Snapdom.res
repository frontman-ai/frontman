
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


type captureResult = {
  url: string,
  toRaw: () => string,
  toImg: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlImageElement>,
  toCanvas: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlCanvasElement>,
  toPng: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlImageElement>,
  toJpg: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlImageElement>,
  toWebp: (~options: captureOptions) => promise<WebAPI.DOMAPI.htmlImageElement>,
}

@module("@zumer/snapdom")
external snapdom: (~element: WebAPI.DOMAPI.element) => promise<captureResult> = "snapdom"