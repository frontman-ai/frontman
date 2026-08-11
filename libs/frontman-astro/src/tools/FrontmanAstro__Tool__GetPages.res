module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanAiFrontmanCore.FrontmanCore__PathContext
module PathStringUtils = FrontmanAiFrontmanCore.FrontmanCore__PathStringUtils

let name = "get_client_pages"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read

let description = `Lists Astro client pages from the pages directory.

Parameters: None

Returns array of page paths based on file-system routing conventions.
Excludes API routes (src/pages/api/) - focuses on renderable pages only.`

@schema
type dynamicType =
  | @as("static") Static
  | @as("single") SingleParam
  | @as("rest") RestParam
  | @as("optional") OptionalParam

@schema
type input = {
  @live
  placeholder?: bool,
}

@schema
type page = {
  @live
  path: string,
  @live
  file: string,
  @live
  isDynamic: bool,
  @live
  dynamicType: dynamicType,
}

@schema
type output = array<page>

let (visibleToAgent, outputJsonSchema) = (true, None)

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

let isDynamicSegment = (segment: string): bool => {
  analyzeDynamicSegment(segment) != Static
}

let fileToRoute = (filePath: string): string => {
  filePath
  ->PathStringUtils.toForwardSlashes
  ->String.replaceRegExp(/\.(astro|md|mdx|html)$/, "")
  ->String.replaceRegExp(/\/index$/, "")
  ->(p => p == "" ? "/" : p)
}

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

let rec findPages = async (
  baseDir: string,
  currentPath: string,
  ~projectRoot: string,
  ~sourceRoot: string,
): array<page> => {
  let fullPath = Path.join([projectRoot, baseDir, currentPath])

  try {
    let entries = await Fs.Promises.readdir(fullPath)

    let pagesArrays = await entries
    ->Array.map(async entry => {
      let entryPath = Path.join([fullPath, entry])
      let stats = await Fs.Promises.lstat(entryPath)

      if Fs.isSymbolicLink(stats) {
        []
      } else if Fs.isDirectory(stats) {
        if entry->String.startsWith("_") || entry == "api" || entry == "components" {
          []
        } else {
          await findPages(baseDir, Path.join([currentPath, entry]), ~projectRoot, ~sourceRoot)
        }
      } else if (
        entry->String.endsWith(".astro") ||
        entry->String.endsWith(".md") ||
        entry->String.endsWith(".mdx") ||
        entry->String.endsWith(".html")
      ) {
        let filePath = Path.join([currentPath, entry])
        let routePath = fileToRoute(filePath)
        let filePathNoExt = filePath->String.replaceRegExp(/\.(astro|md|mdx|html)$/, "")
        let segments =
          filePathNoExt
          ->PathStringUtils.toForwardSlashes
          ->String.split("/")
        let hasDynamic = segments->Array.some(isDynamicSegment)
        let dynType = getMostSignificantDynamicType(segments)
        let relativeToSourceRoot = PathContext.toRelativePath(~sourceRoot, ~absolutePath=entryPath)
        [
          {
            path: routePath,
            file: relativeToSourceRoot,
            isDynamic: hasDynamic,
            dynamicType: dynType,
          },
        ]
      } else {
        []
      }
    })
    ->Promise.all

    pagesArrays->Array.flat
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("")
    if msg->String.includes("ENOENT") {
      []
    } else {
      throw(exn)
    }
  }
}

let execute = async (
  ctx: Tool.serverExecutionContext,
  _input: input,
): Tool.MCP.CallToolResult.t => {
  try {
    let srcPages = await findPages(
      "src/pages",
      "",
      ~projectRoot=ctx.projectRoot,
      ~sourceRoot=ctx.sourceRoot,
    )

    let rootPages = await findPages(
      "pages",
      "",
      ~projectRoot=ctx.projectRoot,
      ~sourceRoot=ctx.sourceRoot,
    )

    let allPages = Array.concat(srcPages, rootPages)

    Tool.unstructuredResult(allPages, outputSchema)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Tool.MCP.CallToolResult.makeError(`Failed to find pages: ${msg}`)
  }
}
