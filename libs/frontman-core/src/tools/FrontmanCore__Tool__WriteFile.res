// Write file tool - writes content to a file (text or binary via image_ref)

module Fs = FrontmanBindings.Fs
module NodeBuffer = FrontmanBindings.NodeBuffer
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.writeFile
let visibleToAgent = true
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content: Text content to write (mutually exclusive with image_ref)
- image_ref: URI of a user-attached image to save (e.g., "attachment://att_abc123/photo.png"). Use this to save images the user has pasted into the chat. Mutually exclusive with content.
- encoding: Set to "base64" when writing binary data (used internally when image_ref is resolved)

Provide either content OR image_ref, not both.
Creates parent directories if they don't exist. Overwrites existing files.
The _context field provides path resolution details for debugging.`

@schema
type input = {
  path: string,
  content?: string,
  @s.describe("URI of a user-attached image to save to disk")
  image_ref?: string,
  @s.describe("Set to 'base64' for binary content (used when image_ref is resolved)")
  encoding?: [#base64],
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

let writeContent = (resolvedPath: string, content: string, encoding: option<[#base64]>) => {
  switch encoding {
  | Some(#base64) =>
    let buffer = NodeBuffer.fromBase64(content)
    Fs.Promises.writeFileBuffer(resolvedPath, buffer)
  | None => Fs.Promises.writeFile(resolvedPath, content)
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  switch (input.content, input.image_ref) {
  | (None, None) => Error("Either content or image_ref must be provided")
  | (Some(_), Some(_)) => Error("Provide either content or image_ref, not both")
  | (None, Some(_)) => Error("image_ref must be resolved to content before execution")
  | (Some(content), None) =>
    switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
    | Error(err) => Error(PathContext.formatError(err))
    | Ok(result) =>
      try {
        let _ = await Fs.Promises.mkdir(PathContext.dirname(result), {recursive: true})
        await writeContent(result.resolvedPath, content, input.encoding)
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
}
