// Get routes tool - lists Next.js routes from the filesystem

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool

let name = "get_routes"
let visibleToAgent = true
let description = `Lists Next.js routes from the app or pages directory.

Parameters: None

Returns array of route paths based on file-system routing conventions.`

@schema
type input = {placeholder?: bool}

@schema
type route = {
  path: string,
  file: string,
  isDynamic: bool,
}

@schema
type output = array<route>

// Check if a segment is dynamic (contains [ ])
let isDynamicSegment = (segment: string): bool => {
  segment->String.startsWith("[") && segment->String.endsWith("]")
}

// Convert file path to route path
let fileToRoute = (filePath: string): string => {
  filePath
  ->String.replaceRegExp(/\.(tsx?|jsx?|mdx?)$/, "")
  ->String.replaceRegExp(/\/page$/, "")
  ->String.replaceRegExp(/\/route$/, "")
  ->String.replaceRegExp(/\/index$/, "")
  ->(p => p == "" ? "/" : p)
}

// Recursively find route files
let rec findRoutes = async (baseDir: string, currentPath: string, ~projectRoot: string): array<
  route,
> => {
  let fullPath = Path.join([projectRoot, baseDir, currentPath])

  try {
    let entries = await Fs.Promises.readdir(fullPath)

    let routesArrays = await entries
    ->Array.map(async entry => {
      let entryPath = Path.join([fullPath, entry])
      let stats = await Fs.Promises.stat(entryPath)

      if Fs.isDirectory(stats) {
        // Skip special directories
        if entry->String.startsWith("_") || entry == "api" || entry == "components" {
          []
        } else {
          await findRoutes(baseDir, Path.join([currentPath, entry]), ~projectRoot)
        }
      } else if (
        entry == "page.tsx" ||
        entry == "page.ts" ||
        entry == "page.jsx" ||
        entry == "page.js" ||
        entry == "route.tsx" ||
        entry == "route.ts"
      ) {
        let routePath = fileToRoute(currentPath)
        let hasDynamic = currentPath->String.split("/")->Array.some(isDynamicSegment)
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

    routesArrays->Array.flat
  } catch {
  | _ => []
  }
}

let execute = async (ctx: Tool.serverExecutionContext, _input: input): Tool.toolResult<output> => {
  try {
    // Try app directory first (Next.js 13+)
    let appRoutes = await findRoutes("src/app", "", ~projectRoot=ctx.projectRoot)
    let appRoutesAlt = await findRoutes("app", "", ~projectRoot=ctx.projectRoot)

    // Try pages directory (legacy)
    let pagesRoutes = await findRoutes("src/pages", "", ~projectRoot=ctx.projectRoot)
    let pagesRoutesAlt = await findRoutes("pages", "", ~projectRoot=ctx.projectRoot)

    let allRoutes = Array.concat(appRoutes, appRoutesAlt)
    let allRoutes = Array.concat(allRoutes, pagesRoutes)
    let allRoutes = Array.concat(allRoutes, pagesRoutesAlt)

    Ok(allRoutes)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to find routes: ${msg}`)
  }
}
