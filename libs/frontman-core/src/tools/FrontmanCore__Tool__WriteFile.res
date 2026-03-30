// Write file tool - writes content to a file (text or binary via image_ref)

module Fs = FrontmanBindings.Fs
module NodeBuffer = FrontmanBindings.NodeBuffer
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FileTracker = FrontmanCore__FileTracker
module ExnUtils = FrontmanCore__ExnUtils

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

Prefer write_file over edit_file when rewriting most of a file — it is more efficient since you only provide the final content once.

IMPORTANT: If the file already exists, you MUST read it with read_file first. The tool will reject writes to existing files that haven't been read.`

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
    | Ok(resolved) =>
      // Guard: existing files must have been read first and not be stale
      let fileExists = try {
        let _ = await Fs.Promises.stat(resolved.resolvedPath)
        true
      } catch {
      | _ => false
      }
      let guardResult = switch fileExists {
      | false => Ok()
      | true => await FileTracker.assertEditSafe(resolved.resolvedPath)
      }
      switch guardResult {
      | Error(msg) => Error(msg)
      | Ok() =>
        try {
          let _ = await Fs.Promises.mkdir(PathContext.dirname(resolved), {recursive: true})
          await writeContent(resolved.resolvedPath, content, input.encoding)
          FileTracker.recordWrite(resolved.resolvedPath)
          Ok({
            _context: {
              sourceRoot: resolved.sourceRoot,
              resolvedPath: resolved.resolvedPath,
              relativePath: resolved.relativePath,
            },
          })
        } catch {
        | exn => Error(`Failed to write file ${input.path}: ${ExnUtils.message(exn)}`)
        }
      }
    }
  }
}
