// Astro Source Annotation bindings
// Reads from window.__frontman_annotations__ API injected by the Frontman Astro integration

// Type matching the annotation data from Astro's data-astro-source-* attributes
// componentProps and displayName are injected by the Frontman props injection
// Vite plugin (via __frontman_props__ HTML comments captured by the annotation script)
type annotation = {
  file: string,
  loc: Nullable.t<string>, // "line:col" format — null when data-astro-source-loc is absent
  componentProps?: Dict.t<JSON.t>,
  displayName?: string,
}

// Type matching window.__frontman_annotations__ API
type annotationsApi = {
  get: WebAPI.DOMAPI.element => Nullable.t<annotation>,
  has: WebAPI.DOMAPI.element => bool,
  size: unit => int,
}

// Access the __frontman_annotations__ API from a window object
let getAnnotationsApi = (window: WebAPI.DOMAPI.window): option<annotationsApi> => {
  let obj = window->Obj.magic
  let annotations: Nullable.t<annotationsApi> = obj["__frontman_annotations__"]
  annotations->Nullable.toOption
}

// Parse "line:col" format into (line, column) tuple
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

// Extract filename from file path for componentName
// e.g., "/src/components/Hero.astro" -> "Hero.astro"
// Handles both / and \ separators for cross-platform compatibility
let extractFilename = (filePath: string): string => {
  filePath
  ->String.replaceAll("\\", "/")
  ->String.split("/")
  ->Array.at(-1)
  ->Option.getOr(filePath)
}
