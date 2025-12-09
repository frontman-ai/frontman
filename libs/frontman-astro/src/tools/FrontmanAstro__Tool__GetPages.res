// Get pages tool - lists Astro pages from the filesystem

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "get_pages"

let description = `Lists Astro pages from the pages directory.

Parameters: None

Returns array of page paths based on file-system routing conventions.`

@schema
type input = {placeholder?: bool}

@schema
type page = {
  path: string,
  file: string,
  isDynamic: bool,
}

@schema
type output = array<page>

// Check if a segment is dynamic (contains [ ])
let isDynamicSegment = (segment: string): bool => {
  segment->String.startsWith("[") && segment->String.endsWith("]")
}

// Convert file path to route path
let fileToRoute = (filePath: string): string => {
  filePath
  ->String.replaceRegExp(%re("/\.(astro|md|mdx)$/"), "")
  ->String.replaceRegExp(%re("/\/index$/"), "")
  ->(p => p == "" ? "/" : p)
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
          entry->String.endsWith(".mdx")
        ) {
          let fileName = entry->String.replaceRegExp(%re("/\.(astro|md|mdx)$/"), "")
          let routePath = fileToRoute(Path.join([currentPath, fileName]))
          let segments = Path.join([currentPath, fileName])->String.split("/")
          let hasDynamic = segments->Array.some(isDynamicSegment)
          [
            {
              path: routePath,
              file: Path.join([baseDir, currentPath, entry]),
              isDynamic: hasDynamic,
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
