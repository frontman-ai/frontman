module Fs = FrontmanBindings.Fs
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FileTracker = FrontmanCore__FileTracker
module ExnUtils = FrontmanCore__ExnUtils
module Matcher = FrontmanCore__Tool__EditFile__Matcher
module FileChange = FrontmanCore__FileChange
module ProtocolFileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange

let name = "edit_file"
let access = Tool.ReadWrite
let description = `Edits a file by replacing text using fuzzy matching.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- oldText (required): The text to find and replace. Must not be empty.
- newText (required): The replacement text (must differ from oldText)
- replaceAll (optional): If true, replaces all occurrences. Default: false.

The tool uses multiple matching strategies (exact, line-trimmed, whitespace-normalized,
indentation-flexible, etc.) to handle common formatting differences.

When replacing most of a file, prefer write_file instead — it avoids reproducing the original content. Use edit_file for surgical changes: a few lines, a function body, a config block. For multiple changes in one file, make several small edit_file calls targeting specific sections rather than one large replacement.

IMPORTANT: You must read_file before editing. The tool will reject edits on unread files.`

@schema
type input = {
  path: string,
  @s.describe("The non-empty text to find.")
  oldText: string,
  @s.describe("The replacement text")
  newText: string,
  @s.describe("Replace all occurrences (default false)")
  replaceAll?: bool,
}

@schema
type pathContext = {
  @live
  sourceRoot: string,
  @live
  resolvedPath: string,
  @live
  relativePath: string,
}

@schema
type output = {
  message: string,
  @live @s.meta({description: "Path resolution context for debugging"})
  _context?: pathContext,
}

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

let toPathCtx = (r: PathContext.resolveResult): pathContext => {
  sourceRoot: r.sourceRoot,
  resolvedPath: r.resolvedPath,
  relativePath: r.relativePath,
}

type execution = FileChange.execution<output>

let findAndReplace = async (
  ~resolved: PathContext.resolveResult,
  ~oldText: string,
  ~newText: string,
  ~replaceAll: bool,
  ~displayPath: string,
): result<execution, string> => {
  try {
    let content = await Fs.Promises.readFile(resolved.resolvedPath)
    let coverageWarning = FileTracker.checkCoverage(resolved.resolvedPath, ~content, ~oldText)

    switch Matcher.applyEdit(~content, ~oldText, ~newText, ~replaceAll) {
    | Applied(newContent) =>
      await Fs.Promises.writeFile(resolved.resolvedPath, newContent)
      let stats = await Fs.Promises.stat(resolved.resolvedPath)
      FileTracker.recordWrite(
        resolved.resolvedPath,
        ~mtimeMs=Fs.mtimeMs(stats),
        ~size=Fs.size(stats),
      )
      let message = switch coverageWarning {
      | Some(warning) => `Edit applied successfully.\n\n${warning}`
      | None => "Edit applied successfully."
      }
      Ok({
        output: {message, _context: toPathCtx(resolved)},
        fileChange: FileChange.make(
          ~path=resolved.relativePath,
          ~status=ProtocolFileChange.Modified,
          ~oldText=Some(content),
          ~currentText=Some(newContent),
          ~binary=FileChange.isBinary(content) || FileChange.isBinary(newContent),
        ),
      })
    | NotFound =>
      Error(
        `oldText not found in file ${displayPath}. Make sure the text matches exactly, or read the file again to see its current content.`,
      )
    | Ambiguous =>
      Error(
        `Found multiple matches for oldText in ${displayPath}. Provide more surrounding context to identify the correct match, or use replaceAll to replace all occurrences.`,
      )
    }
  } catch {
  | exn => Error(`Failed to edit file ${displayPath}: ${ExnUtils.message(exn)}`)
  }
}

let executeOutput = async (ctx: Tool.serverExecutionContext, input: input): result<
  execution,
  string,
> => {
  switch input.oldText == input.newText {
  | true => Error("oldText and newText must be different")
  | false =>
    switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
    | Error(err) => Error(PathContext.formatError(err))
    | Ok(resolved) =>
      switch input.oldText {
      | "" => Error("oldText must not be empty; use write_file to create files")
      | oldText =>
        switch await FileTracker.assertEditSafe(resolved.resolvedPath) {
        | Error(msg) => Error(msg)
        | Ok() =>
          await findAndReplace(
            ~resolved,
            ~oldText,
            ~newText=input.newText,
            ~replaceAll=input.replaceAll->Option.getOr(false),
            ~displayPath=input.path,
          )
        }
      }
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await executeOutput(ctx, input) {
  | Ok({output, fileChange}) =>
    FileChange.textResultWithFileChange(~message=output.message, ~output, ~outputSchema, fileChange)
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
