// Edit file tool - find-and-replace with fuzzy matching
//
// Two distinct operations:
// - Create: oldText is empty → write newText to a new file
// - Edit: oldText is non-empty → find-and-replace in an existing file
//
// The edit path uses a multi-strategy matcher that gracefully handles common
// LLM mistakes (wrong indentation, extra whitespace, escaped characters, etc.)
// and requires the file to have been read first via read_file.

module Fs = FrontmanBindings.Fs
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FileTracker = FrontmanCore__FileTracker
module ExnUtils = FrontmanCore__ExnUtils
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

When replacing most of a file, prefer write_file instead — it avoids reproducing the original content. Use edit_file for surgical changes: a few lines, a function body, a config block. For multiple changes in one file, make several small edit_file calls targeting specific sections rather than one large replacement.

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

// ── Domain helpers ─────────────────────────────────────────────────────

let toPathCtx = (r: PathContext.resolveResult): pathContext => {
  sourceRoot: r.sourceRoot,
  resolvedPath: r.resolvedPath,
  relativePath: r.relativePath,
}

// Create a new file (oldText is empty).
let createFile = async (
  ~resolved: PathContext.resolveResult,
  ~content: string,
  ~displayPath: string,
): Tool.toolResult<output> => {
  try {
    let _ = await Fs.Promises.mkdir(PathContext.dirname(resolved), {recursive: true})
    await Fs.Promises.writeFile(resolved.resolvedPath, content)
    let stats = await Fs.Promises.stat(resolved.resolvedPath)
    FileTracker.recordWrite(resolved.resolvedPath, ~mtimeMs=Fs.mtimeMs(stats), ~size=Fs.size(stats))
    Ok({message: "File created successfully.", _context: toPathCtx(resolved)})
  } catch {
  | exn => Error(`Failed to create file ${displayPath}: ${ExnUtils.message(exn)}`)
  }
}

// Find oldText in the file, replace it, and write back.
// Includes a coverage warning when the edit target is outside previously-read ranges.
let findAndReplace = async (
  ~resolved: PathContext.resolveResult,
  ~oldText: string,
  ~newText: string,
  ~replaceAll: bool,
  ~displayPath: string,
): Tool.toolResult<output> => {
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
      Ok({message, _context: toPathCtx(resolved)})
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

// ── Execute ────────────────────────────────────────────────────────────

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  switch input.oldText == input.newText {
  | true => Error("oldText and newText must be different")
  | false =>
    switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
    | Error(err) => Error(PathContext.formatError(err))
    | Ok(resolved) =>
      switch input.oldText {
      // Explicit create: empty oldText means "write a new file"
      | "" => await createFile(~resolved, ~content=input.newText, ~displayPath=input.path)
      // Edit: find-and-replace in an existing, previously-read file
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
