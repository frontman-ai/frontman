// Read file tool - reads file content with optional offset/limit

module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.readFile
let visibleToAgent = true
let description = `Reads a file from the filesystem.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- offset (optional): Line number to start from (0-indexed, default: 0). Pass null or 0 to start from beginning.
- limit (optional): Maximum lines to read (default: 500). Pass null or 500 for default.

Returns file content with metadata about total lines and whether more content exists.
The _context field provides path resolution details for debugging.`

@schema
type input = {
  path: string,
  @s.default(0) offset?: int,
  @s.default(500) limit?: int,
}

@schema
type pathContext = {
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

@schema
type output = {
  content: string,
  totalLines: int,
  hasMore: bool,
  @s.meta({description: "Path resolution context for debugging"})
  _context?: pathContext,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let offset = input.offset->Option.getOr(0)
  let limit = input.limit->Option.getOr(500)

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    try {
      let content = await Fs.Promises.readFile(result.resolvedPath)
      let lines = content->String.split("\n")
      let totalLines = lines->Array.length

      let selectedLines = lines->Array.slice(~start=offset, ~end=offset + limit)
      let selectedContent = selectedLines->Array.join("\n")
      let hasMore = offset + limit < totalLines

      Ok({
        content: selectedContent,
        totalLines,
        hasMore,
        _context: {
          sourceRoot: result.sourceRoot,
          resolvedPath: result.resolvedPath,
          relativePath: result.relativePath,
        },
      })
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to read file ${input.path}: ${msg}`)
    }
  }
}
