// Astro Source Detection - reads from window.__frontman_annotations__ API
// This API is injected by FrontmanAstro__Middleware into Astro pages

// Type matching the annotation data from Astro's data-astro-source-* attributes
type annotation = {
  file: string,
  loc: string, // "line:col" format
}

// Type matching window.__frontman_annotations__ API
type annotationsApi = {
  get: WebAPI.DOMAPI.element => Nullable.t<annotation>,
  has: WebAPI.DOMAPI.element => bool,
  size: unit => int,
}

// Helper to access __frontman_annotations__ from a window object
let getAnnotationsApi = (window: WebAPI.DOMAPI.window): option<annotationsApi> => {
  let obj = window->Obj.magic
  let annotations: Nullable.t<annotationsApi> = obj["__frontman_annotations__"]
  annotations->Nullable.toOption
}

// Parse "line:col" format into (line, column) tuple
let parseLoc = (loc: string): option<(int, int)> => {
  switch loc->String.split(":") {
  | [lineStr, colStr] =>
    Int.fromString(lineStr)->Option.flatMap(line =>
      Int.fromString(colStr)->Option.map(col => (line, col))
    )
  | _ => None
  }
}

// Extract filename from file path for componentName
// e.g., "/src/components/Hero.astro" -> "Hero.astro"
let extractFilename = (filePath: string): string => {
  filePath->String.split("/")->Array.at(-1)->Option.getOr(filePath)
}

// Get source location for an element using Astro annotations
let getElementSourceLocation = (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  getAnnotationsApi(window)
  ->Option.flatMap(api => api.get(element)->Nullable.toOption)
  ->Option.flatMap(annotation =>
    parseLoc(annotation.loc)->Option.map(((line, column)) => {
      Client__Types.SourceLocation.componentName: Some(extractFilename(annotation.file)),
      tagName: element.tagName->String.toLowerCase,
      file: annotation.file,
      line,
      column,
      parent: None,
      componentProps: None,
    })
  )
}
