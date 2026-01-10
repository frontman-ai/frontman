// Read file tool - reads file content with optional offset/limit

module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath

let name = "read_file"
let visibleToAgent = true
let description = `Reads a file from the filesystem.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- offset (optional): Line number to start from (0-indexed, default: 0)
- limit (optional): Maximum lines to read (default: 500)

Returns file content with metadata about total lines and whether more content exists.`

@schema
type input = {
  path: string,
  @s.default(0) offset?: int,
  @s.default(500) limit?: int,
}

@schema
type output = {
  content: string,
  totalLines: int,
  hasMore: bool,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let offset = input.offset->Option.getOr(0)
  let limit = input.limit->Option.getOr(500)

  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(msg) => Error(msg)
  | Ok(safePath) =>
    try {
      let content = await Fs.Promises.readFile(SafePath.toString(safePath))
      let lines = content->String.split("\n")
      let totalLines = lines->Array.length

      let selectedLines = lines->Array.slice(~start=offset, ~end=offset + limit)
      let selectedContent = selectedLines->Array.join("\n")
      let hasMore = offset + limit < totalLines

      Ok({
        content: selectedContent,
        totalLines,
        hasMore,
      })
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to read file ${input.path}: ${msg}`)
    }
  }
}
