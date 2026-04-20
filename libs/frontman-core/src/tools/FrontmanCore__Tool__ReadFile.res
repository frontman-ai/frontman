// Read file tool - reads file content with optional offset/limit

module Fs = FrontmanBindings.Fs
module Path = FrontmanBindings.Path
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FsUtils = FrontmanCore__FsUtils
module SearchFiles = FrontmanCore__Tool__SearchFiles
module ListTree = FrontmanCore__Tool__ListTree
module PathRecovery = FrontmanCore__PathRecovery
module ToolPathHints = FrontmanCore__ToolPathHints

let name = Tool.ToolNames.readFile
let visibleToAgent = true
let description = `Reads a file from the filesystem.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- offset (optional): Line number to start from (0-indexed, default: 0). Pass null or 0 to start from beginning.
- limit (optional): Maximum lines to read (default: 500). Pass null or 500 for default.

Returns file content with metadata about total lines and whether more content exists.
The _context field provides path resolution details for debugging.

When hasMore is true, the file has content beyond what was returned. For large files:
- Use grep first to find the line numbers of relevant sections, then read_file with a targeted offset.
- Don't read sequentially from the top — jump to the section you need.
- For React/Vue/Astro components, locate the render/return block before editing.`

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

let sortStrings = (items: array<string>): array<string> => {
  items->Array.toSorted((a, b) => {
    switch String.compare(a, b) {
    | n if n < 0.0 => -1.0
    | n if n > 0.0 => 1.0
    | _ => 0.0
    }
  })
}

let previewLines = (text: string, ~maxLines: int): string => {
  let lines = text->String.split("\n")
  let visible = lines->Array.slice(~start=0, ~end=maxLines)
  let suffix = switch Array.length(lines) > maxLines {
  | true => "\n..."
  | false => ""
  }

  visible->Array.join("\n") ++ suffix
}

let readResolvedFile = async (
  ~ctx: Tool.serverExecutionContext,
  ~resolved: PathContext.resolveResult,
  ~offset: int,
  ~limit: int,
): Tool.toolResult<output> => {
  try {
    let stats = await Fs.Promises.stat(resolved.resolvedPath)
    let content = await Fs.Promises.readFile(resolved.resolvedPath)
    let lines = content->String.split("\n")
    let totalLines = lines->Array.length

    let selectedLines = lines->Array.slice(~start=offset, ~end=offset + limit)
    let selectedContent = selectedLines->Array.join("\n")
    let hasMore = offset + limit < totalLines

    // Track that this file was read (for edit_file safety)
    FrontmanCore__FileTracker.recordRead(
      resolved.resolvedPath,
      ~offset,
      ~limit,
      ~totalLines,
      ~mtimeMs=Fs.mtimeMs(stats),
      ~size=Fs.size(stats),
    )

    ToolPathHints.recordReadSuccess(~sourceRoot=ctx.sourceRoot, ~relativePath=resolved.relativePath)

    Ok({
      content: selectedContent,
      totalLines,
      hasMore,
      _context: {
        sourceRoot: resolved.sourceRoot,
        resolvedPath: resolved.resolvedPath,
        relativePath: resolved.relativePath,
      },
    })
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to read file ${resolved.relativePath}: ${msg}`)
  }
}

let buildMissingPathError = async (
  ~ctx: Tool.serverExecutionContext,
  ~requestedPath: string,
  ~resolved: PathContext.resolveResult,
): string => {
  let zeroSearch = ToolPathHints.findBlockingZeroSearch(
    ~sourceRoot=ctx.sourceRoot,
    ~requestedRelativePath=resolved.relativePath,
  )

  let zeroSearchMsg = switch zeroSearch {
  | Some(z) =>
    `Zero-result guardrail: search_files pattern "${z.pattern}" returned 0 results under "${z.searchRoot}". Blind read_file retries are blocked.`
  | None => "Discovery-before-read guardrail: path is unknown and does not exist. Use discovery tools before retrying read_file."
  }

  let anchors = ToolPathHints.getAnchors(~sourceRoot=ctx.sourceRoot)->Array.slice(~start=0, ~end=6)

  switch await PathRecovery.recoverMissingPath(
    ~sourceRoot=ctx.sourceRoot,
    ~resolvedPath=resolved.resolvedPath,
  ) {
  | None => {
      let anchorsLine = switch anchors {
      | [] => ""
      | _ => "\nKnown anchors: " ++ anchors->sortStrings->Array.join(", ")
      }

      `File not found: ${requestedPath}
Resolved path: ${resolved.relativePath}
${zeroSearchMsg}${anchorsLine}

Next steps:
- broaden search_files pattern
- run list_tree on a nearby parent directory
- retry read_file only with a discovered path`
    }

  | Some(recovery) =>
    let siblingPreview = switch recovery.siblingEntries {
    | [] => "(none)"
    | entries => entries->Array.join(", ")
    }

    let basename = resolved.relativePath->Path.basename

    let candidateFiles = switch await SearchFiles.execute(
      ctx,
      {
        pattern: basename,
        path: ?Some(recovery.nearestDirRelative),
        maxResults: ?Some(8),
      },
    ) {
    | Ok(output) => output.files
    | Error(_) => []
    }

    let candidatesLine = switch candidateFiles {
    | [] => "Candidate files: (none)"
    | files => "Candidate files: " ++ files->Array.join(", ")
    }

    let treePreview = switch await ListTree.execute(
      ctx,
      {
        path: ?Some(recovery.nearestDirRelative),
        depth: ?Some(2),
      },
    ) {
    | Ok(output) => Some(output.tree->previewLines(~maxLines=20))
    | Error(_) => None
    }

    let treeSection = switch treePreview {
    | Some(tree) => "\nRecovered tree preview:\n" ++ tree
    | None => ""
    }

    let anchorsLine = switch anchors {
    | [] => ""
    | _ => "\nKnown anchors: " ++ anchors->sortStrings->Array.join(", ")
    }

    `File not found: ${requestedPath}
Resolved path: ${resolved.relativePath}
${zeroSearchMsg}
Nearest existing parent: ${recovery.nearestDirRelative}
Parent entries: ${siblingPreview}
${candidatesLine}${anchorsLine}${treeSection}

Next steps:
- broaden search_files pattern if candidates are empty
- use list_tree/list_files around ${recovery.nearestDirRelative}
- retry read_file only with a discovered path`
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let offset = input.offset->Option.getOr(0)
  let limit = input.limit->Option.getOr(500)

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    switch await FsUtils.fileExists(result.resolvedPath) {
    | true => await readResolvedFile(~ctx, ~resolved=result, ~offset, ~limit)
    | false => Error(await buildMissingPathError(~ctx, ~requestedPath=input.path, ~resolved=result))
    }
  }
}
