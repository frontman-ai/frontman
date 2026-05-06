// Capture options for snapdom
// See: https://github.com/zumerlab/snapdom#options
type captureOptions = {
  scale?: float,
  quality?: float,
}

// Snapdom returns an image element with a data URL in its src
// This represents HTMLImageElement but we only care about the src property
type snapshotImage = {src: string}

type captureResult = {
  toCanvas: captureOptions => promise<WebAPI.DOMAPI.htmlCanvasElement>,
  toJpg: captureOptions => promise<snapshotImage>,
}

// Main capture function
// Returns a captureResult with methods to export in various formats
@module("@zumer/snapdom")
external snapdom: WebAPI.DOMAPI.element => promise<captureResult> = "snapdom"
