// Shared path utilities for framework source detection modules.
// Used by Vue, Astro, and future framework detections to avoid duplication.

module PathStringUtils = Client__PathStringUtils

// Check if a file path is from node_modules (third-party component).
// Components from node_modules are skipped during source detection since
// the user cares about their own source code, not library internals.
let isNodeModulesPath = (filePath: string): bool => {
  filePath->String.includes("node_modules")
}

// Extract the filename from a file path for use as a component display name.
// Normalizes Windows backslashes to forward slashes before splitting.
// e.g., "/src/components/Hero.vue" -> "Hero.vue"
//        "C:\\Users\\dev\\App.astro" -> "App.astro"
let extractFilename = (filePath: string): string => {
  filePath
  ->PathStringUtils.toForwardSlashes
  ->String.split("/")
  ->Array.at(-1)
  // String.split always returns at least one element — crash if invariant breaks
  ->Option.getOrThrow
}

// Parse "line:col" format into (line, column) tuple.
// Used by Astro source detection to interpret data-astro-source-loc annotations.
let parseLoc = (loc: Nullable.t<string>): option<(int, int)> => {
  switch loc->Nullable.toOption {
  | None => None
  | Some(locStr) =>
    switch locStr->String.split(":") {
    | [lineStr, colStr] =>
      Int.fromString(lineStr)->Option.flatMap(line =>
        Int.fromString(colStr)->Option.map(col => (line, col))
      )
    | _ => None
    }
  }
}
