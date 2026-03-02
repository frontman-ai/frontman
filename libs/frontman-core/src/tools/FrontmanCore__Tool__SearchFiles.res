// SearchFiles tool - fast file name search using ripgrep with git ls-files fallback

module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.searchFiles
let visibleToAgent = true
let description = `Searches **file names** across the project. Returns file paths whose name matches a pattern.

Use search_files to locate files by name — "find the Button component", "where are the test files". This does NOT search file contents; use grep for that. Use list_tree for a structural overview of the project.

PARAMETERS:
- pattern (required): Filename pattern to match (supports glob-like: "*.test.ts", "config", "Button*")
- path (optional): Directory to search in (defaults to source root). If a file path is given, searches in its parent directory.
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Locate a component: pattern="Button"
- Find test files: pattern="*.test.ts"
- Find configs in a subdirectory: pattern="*.json", path="src/config"

OUTPUT:
List of matching file paths, sorted by modification time (newest first).

LIMITATIONS:
- Results capped at max_results (default 20)
- Matches file names only, not directory names
- Hidden files (dotfiles) are included`

@schema
type input = {
  pattern: string,
  path?: string,
  @as("max_results") @s.default(20) maxResults?: int,
}

@schema
type output = {
  files: array<string>,
  totalResults: int,
  truncated: bool,
}

// Get ripgrep path from @vscode/ripgrep package
let getRipgrepPath = (): option<string> => {
  try {
    let vsCodeRipgrep = %raw(`require('@vscode/ripgrep')`)
    Some(vsCodeRipgrep["rgPath"])
  } catch {
  | _ => None
  }
}

// Build ripgrep arguments for file search
let buildRipgrepArgs = (~searchPath: string): array<string> => {
  let args = []

  // List files only (not content)
  args->Array.push("--files")

  // Hidden files included
  args->Array.push("--hidden")

  // Don't respect gitignore
  args->Array.push("--no-ignore")

  // Search path
  args->Array.push(searchPath)

  args
}

// Check if a filename matches a pattern (case-insensitive, glob-like)
let matchesPattern = (fileName: string, ~patternLower: string): bool => {
  let fileNameLower = fileName->String.toLowerCase

  switch patternLower {
  | "" => true
  | p if p->String.includes("*") => {
      let parts = p->String.split("*")
      let partsLength = Array.length(parts)

      parts->Array.reduceWithIndex(true, (matches, part, idx) =>
        switch (matches, part) {
        | (false, _) => false
        | (_, "") => true
        | _ if idx === 0 => fileNameLower->String.startsWith(part)
        | _ if idx === partsLength - 1 => fileNameLower->String.endsWith(part)
        | _ => fileNameLower->String.includes(part)
        }
      )
    }
  | p => fileNameLower->String.includes(p)
  }
}

// Filter file paths by pattern and paginate results.
// Shared by both the ripgrep and git ls-files code paths.
let filterAndPaginate = (lines: array<string>, ~pattern: string, ~maxResults: int): output => {
  let patternLower = pattern->String.toLowerCase

  let matchedFiles = lines->Array.filter(filePath => {
    let fileName = Path.basename(filePath)
    matchesPattern(fileName, ~patternLower)
  })

  let truncated = Array.length(matchedFiles) > maxResults
  let files = matchedFiles->Array.slice(~start=0, ~end=maxResults)

  {
    files,
    totalResults: Array.length(matchedFiles),
    truncated,
  }
}

// Execute ripgrep for file search using spawn (no shell)
let executeRipgrep = async (
  ~rgPath: string,
  ~pattern: string,
  ~searchPath: string,
  ~maxResults: int,
): result<output, string> => {
  let args = buildRipgrepArgs(~searchPath)

  let result = await ChildProcess.spawnResult(rgPath, args)

  switch result {
  | Ok({stdout}) => {
      let lines = stdout->String.trim->String.split("\n")->Array.filter(line => line !== "")
      Ok(filterAndPaginate(lines, ~pattern, ~maxResults))
    }
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalResults: 0, truncated: false})
  | Error({stderr}) => Error(`Ripgrep failed: ${stderr}`)
  }
}

// Execute git ls-files using spawn (no shell) and filter results in-process.
// The old approach piped through `grep -i` via a shell string, which broke on
// patterns containing spaces or special characters.
let executeGitLsFiles = async (
  ~pattern: string,
  ~searchPath: string,
  ~maxResults: int,
): result<output, string> => {
  let result = await ChildProcess.spawnResult("git", ["ls-files"], ~cwd=searchPath)

  switch result {
  | Ok({stdout}) => {
      let lines = stdout->String.trim->String.split("\n")->Array.filter(line => line !== "")
      Ok(filterAndPaginate(lines, ~pattern, ~maxResults))
    }
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalResults: 0, truncated: false})
  | Error({stderr}) => Error(`Git ls-files failed: ${stderr}`)
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  // resolveSearchDir ensures we always get a directory, even if the agent
  // passes a file path (e.g. "src/Button.tsx" → "src/").
  let searchPath = await PathContext.resolveSearchDir(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path)
  let maxResults = input.maxResults->Option.getOr(20)

  // Try ripgrep first, fall back to git ls-files
  switch getRipgrepPath() {
  | Some(rgPath) =>
    let result = await executeRipgrep(
      ~rgPath,
      ~pattern=input.pattern,
      ~searchPath,
      ~maxResults,
    )

    switch result {
    | Ok(_) => result
    | Error(_) =>
      // Fallback to git ls-files
      await executeGitLsFiles(~pattern=input.pattern, ~searchPath, ~maxResults)
    }
  | None =>
    // No ripgrep, use git ls-files
    await executeGitLsFiles(~pattern=input.pattern, ~searchPath, ~maxResults)
  }
}

