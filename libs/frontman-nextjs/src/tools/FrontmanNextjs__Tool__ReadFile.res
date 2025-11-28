// Read file tool - reads file content with optional offset/limit

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "read_file"

let description = `Reads a file from the filesystem.

Parameters:
- path (required): Relative path to file from project root
- offset (optional): Line number to start from (0-indexed, default: 0)
- limit (optional): Maximum lines to read (default: 500)

Returns file content with metadata about total lines and whether more content exists.`

@schema
type input = {
  path: string,
  @s.default(0) offset: int,
  @s.default(500) limit: int,
}

@schema
type output = {
  content: string,
  totalLines: int,
  hasMore: bool,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let fullPath = Path.join([ctx.projectRoot, input.path])

  try {
    let content = await Fs.Promises.readFile(fullPath)
    let lines = content->String.split("\n")
    let totalLines = lines->Array.length

    let selectedLines = lines->Array.slice(~start=input.offset, ~end=input.offset + input.limit)
    let selectedContent = selectedLines->Array.join("\n")
    let hasMore = input.offset + input.limit < totalLines

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
