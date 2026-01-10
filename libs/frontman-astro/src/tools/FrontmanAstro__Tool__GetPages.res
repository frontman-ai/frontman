// Get client pages tool - lists Astro pages from the filesystem
// Excludes API routes (src/pages/api/) - use a separate tool for those

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool

let name = "get_client_pages"
let visibleToAgent = true

let description = `Lists Astro client pages from the pages directory.

Parameters: None

Returns array of page paths based on file-system routing conventions.
Excludes API routes (src/pages/api/) - focuses on renderable pages only.`

// Dynamic route types in Astro
type dynamicType =
  | Static // no brackets
  | SingleParam // [slug]
  | RestParam // [...slug]
  | OptionalParam // [[slug]]

@schema
type input = {placeholder?: bool}

@schema
type page = {
  path: string,
  file: string,
  isDynamic: bool,
  dynamicType: string, // "static" | "single" | "rest" | "optional"
}

@schema
type output = array<page>

// Analyze a segment for dynamic route type
let analyzeDynamicSegment = (segment: string): dynamicType => {
  if segment->String.startsWith("[[") && segment->String.endsWith("]]") {
    OptionalParam
  } else if segment->String.startsWith("[...") && segment->String.endsWith("]") {
    RestParam
  } else if segment->String.startsWith("[") && segment->String.endsWith("]") {
    SingleParam
  } else {
    Static
  }
}

// Convert dynamicType to string for JSON output
let dynamicTypeToString = (dt: dynamicType): string => {
  switch dt {
  | Static => "static"
  | SingleParam => "single"
  | RestParam => "rest"
  | OptionalParam => "optional"
  }
}

// Check if segment is any kind of dynamic
let isDynamicSegment = (segment: string): bool => {
  analyzeDynamicSegment(segment) != Static
}

// Convert file path to route path
let fileToRoute = (filePath: string): string => {
  filePath
  ->String.replaceRegExp(%re("/\.(astro|md|mdx|html)$/"), "")
  ->String.replaceRegExp(%re("/\/index$/"), "")
  ->(p => p == "" ? "/" : p)
}

// Get the most significant dynamic type from all segments
// Priority: rest > optional > single > static
let getMostSignificantDynamicType = (segments: array<string>): dynamicType => {
  segments->Array.reduce(Static, (acc, segment) => {
    let segType = analyzeDynamicSegment(segment)
    switch (acc, segType) {
    | (_, RestParam) => RestParam
    | (RestParam, _) => RestParam
    | (_, OptionalParam) => OptionalParam
    | (OptionalParam, _) => OptionalParam
    | (_, SingleParam) => SingleParam
    | (SingleParam, _) => SingleParam
    | _ => Static
    }
  })
}

// Recursively find page files
let rec findPages = async (
  baseDir: string,
  currentPath: string,
  ~projectRoot: string,
): array<page> => {
  let fullPath = Path.join([projectRoot, baseDir, currentPath])

  try {
    let entries = await Fs.Promises.readdir(fullPath)

    let pagesArrays =
      await entries
      ->Array.map(async entry => {
        let entryPath = Path.join([fullPath, entry])
        let stats = await Fs.Promises.stat(entryPath)

        if Fs.isDirectory(stats) {
          // Skip special directories
          if entry->String.startsWith("_") || entry == "api" || entry == "components" {
            []
          } else {
            await findPages(baseDir, Path.join([currentPath, entry]), ~projectRoot)
          }
        } else if (
          entry->String.endsWith(".astro") ||
          entry->String.endsWith(".md") ||
          entry->String.endsWith(".mdx") ||
          entry->String.endsWith(".html")
        ) {
          let fileName = entry->String.replaceRegExp(%re("/\.(astro|md|mdx|html)$/"), "")
          let routePath = fileToRoute(Path.join([currentPath, fileName]))
          let segments = Path.join([currentPath, fileName])->String.split("/")
          let hasDynamic = segments->Array.some(isDynamicSegment)
          let dynType = getMostSignificantDynamicType(segments)
          [
            {
              path: routePath,
              file: Path.join([baseDir, currentPath, entry]),
              isDynamic: hasDynamic,
              dynamicType: dynamicTypeToString(dynType),
            },
          ]
        } else {
          []
        }
      })
      ->Promise.all

    pagesArrays->Array.flat
  } catch {
  | _ => []
  }
}

let execute = async (ctx: Tool.serverExecutionContext, _input: input): Tool.toolResult<output> => {
  try {
    // Try src/pages directory first
    let srcPages = await findPages("src/pages", "", ~projectRoot=ctx.projectRoot)

    // Try pages directory (legacy)
    let rootPages = await findPages("pages", "", ~projectRoot=ctx.projectRoot)

    let allPages = Array.concat(srcPages, rootPages)

    Ok(allPages)
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to find pages: ${msg}`)
  }
}
