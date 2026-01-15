// Write file tool - writes content to a file

module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = "write_file"
let visibleToAgent = true
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content (required): Content to write

Creates parent directories if they don't exist. Overwrites existing files.
The _context field provides path resolution details for debugging.`

@schema
type input = {
  path: string,
  content: string,
}

@schema
type pathContext = {
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

@schema
type output = {
  @s.meta({description: "Path resolution context for debugging"})
  _context?: pathContext,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    let dirPath = PathContext.dirname(result)
    try {
      let _ = await Fs.Promises.mkdir(dirPath, {recursive: true})
      await Fs.Promises.writeFile(result.resolvedPath, input.content)
      Ok({
        _context: {
          sourceRoot: result.sourceRoot,
          resolvedPath: result.resolvedPath,
          relativePath: result.relativePath,
        },
      })
    } catch {
    | exn =>
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to write file ${input.path}: ${msg}`)
    }
  }
}
