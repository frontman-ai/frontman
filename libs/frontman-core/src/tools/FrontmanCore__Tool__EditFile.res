// Edit file tool - find-and-replace with fuzzy matching
//
// Uses a multi-strategy matcher that gracefully handles common LLM mistakes
// (wrong indentation, extra whitespace, escaped characters, etc.)
// Requires the file to have been read first via read_file.

module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FileTracker = FrontmanCore__FileTracker
module Matcher = FrontmanCore__Tool__EditFile__Matcher

let name = "edit_file"
let visibleToAgent = true
let description = `Edits a file by replacing text using fuzzy matching.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- oldText (required): The text to find and replace. An empty oldText creates a new file with newText as content.
- newText (required): The replacement text (must differ from oldText)
- replaceAll (optional): If true, replaces all occurrences. Default: false.

The tool uses multiple matching strategies (exact, line-trimmed, whitespace-normalized,
indentation-flexible, etc.) to handle common formatting differences.

IMPORTANT: You must read_file before editing. The tool will reject edits on unread files.`

@schema
type input = {
  path: string,
  @s.describe("The text to find. Empty string creates a new file.")
  oldText: string,
  @s.describe("The replacement text")
  newText: string,
  @s.describe("Replace all occurrences (default false)")
  replaceAll?: bool,
}

@schema
type pathContext = {
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

@schema
type output = {
  message: string,
  @s.meta({description: "Path resolution context for debugging"})
  _context?: pathContext,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let replaceAll = input.replaceAll->Option.getOr(false)

  // oldText and newText must differ
  switch input.oldText == input.newText {
  | true => Error("oldText and newText must be different")
  | false =>
    switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
    | Error(err) => Error(PathContext.formatError(err))
    | Ok(result) =>
      let pathCtx = {
        sourceRoot: result.sourceRoot,
        resolvedPath: result.resolvedPath,
        relativePath: result.relativePath,
      }

      // Empty oldText = create new file
      switch input.oldText == "" {
      | true =>
        try {
          let dirPath = PathContext.dirname(result)
          let _ = await Fs.Promises.mkdir(dirPath, {recursive: true})
          await Fs.Promises.writeFile(result.resolvedPath, input.newText)
          Ok({
            message: "File created successfully.",
            _context: pathCtx,
          })
        } catch {
        | exn =>
          let msg =
            exn
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("Unknown error")
          Error(`Failed to create file ${input.path}: ${msg}`)
        }
      | false =>
        // Read-before-edit safety check
        switch FileTracker.assertReadBefore(result.resolvedPath) {
        | Error(msg) => Error(msg)
        | Ok() =>
          try {
            let content = await Fs.Promises.readFile(result.resolvedPath)

            switch Matcher.applyEdit(
              ~content,
              ~oldText=input.oldText,
              ~newText=input.newText,
              ~replaceAll,
            ) {
            | Applied(newContent) =>
              await Fs.Promises.writeFile(result.resolvedPath, newContent)
              Ok({
                message: "Edit applied successfully.",
                _context: pathCtx,
              })
            | NotFound =>
              Error(
                `oldText not found in file ${input.path}. Make sure the text matches exactly, or read the file again to see its current content.`,
              )
            | Ambiguous =>
              Error(
                `Found multiple matches for oldText in ${input.path}. Provide more surrounding context to identify the correct match, or use replaceAll to replace all occurrences.`,
              )
            }
          } catch {
          | exn =>
            let msg =
              exn
              ->JsExn.fromException
              ->Option.flatMap(JsExn.message)
              ->Option.getOr("Unknown error")
            Error(`Failed to edit file ${input.path}: ${msg}`)
          }
        }
      }
    }
  }
}
