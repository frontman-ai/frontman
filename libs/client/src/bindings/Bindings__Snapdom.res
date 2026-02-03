// Capture options for snapdom
// See: https://github.com/zumerlab/snapdom#options
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
  cache?: string, // "disabled" | "soft" | "auto" | "full"
  exclude?: array<string>,
  excludeMode?: string, // "hide" | "remove"
  filter?: WebAPI.DOMAPI.element => bool, // Note: no labeled parameter
  filterMode?: string, // "hide" | "remove"
  placeholders?: bool,
  embedFonts?: bool,
  outerTransforms?: bool,
  outerShadows?: bool,
  fallbackURL?: string,
}

// Download-specific options (extends captureOptions)
type downloadOptions = {
  ...captureOptions,
  filename?: string,
  format?: string, // "png" | "jpeg" | "jpg" | "webp" | "svg"
}

// Blob-specific options (extends captureOptions)
type blobOptions = {
  ...captureOptions,
  @as("type") blobType?: string, // "svg" | "png" | "jpeg" | "jpg" | "webp"
}

// Snapdom returns an image element with a data URL in its src
// This represents HTMLImageElement but we only care about the src property
type snapshotImage = {src: string}

type captureResult = {
  url: string,
  toRaw: unit => string,
  @deprecated("Use toSvg instead")
  toImg: captureOptions => promise<snapshotImage>,
  toSvg: captureOptions => promise<snapshotImage>,
  toCanvas: captureOptions => promise<WebAPI.DOMAPI.htmlCanvasElement>,
  toBlob: blobOptions => promise<WebAPI.FileAPI.blob>,
  toPng: captureOptions => promise<snapshotImage>,
  toJpg: captureOptions => promise<snapshotImage>,
  toWebp: captureOptions => promise<snapshotImage>,
  download: downloadOptions => promise<unit>,
}

// Main capture function
// Returns a captureResult with methods to export in various formats
@module("@zumer/snapdom")
external snapdom: WebAPI.DOMAPI.element => promise<captureResult> = "snapdom"

// With options variant
@module("@zumer/snapdom")
external snapdomWithOptions: (
  WebAPI.DOMAPI.element,
  captureOptions,
) => promise<captureResult> = "snapdom"
