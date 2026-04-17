// SearchFiles tool - fast file name search using ripgrep with git ls-files fallback

module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module PathRecovery = FrontmanCore__PathRecovery
module ToolPathHints = FrontmanCore__ToolPathHints
module FilenamePattern = FrontmanCore__FilenamePattern

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

type backendError = {
  backend: string,
  command: string,
  cwd: string,
  exitCode: option<int>,
  stderr: string,
  message: string,
  targetPath: string,
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

let matchesPattern = (fileName: string, ~patternLower: string): bool =>
  FilenamePattern.matchesPattern(~pattern=patternLower, ~text=fileName)

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

let trimForError = (value: string): string => {
  let trimmed = value->String.trim
  switch trimmed == "" {
  | true => "(empty)"
  | false => trimmed
  }
}

let formatExitCode = (code: option<int>): string => {
  switch code {
  | Some(value) => Int.toString(value)
  | None => "none"
  }
}

let makeBackendError = (
  ~backend: string,
  ~command: string,
  ~cwd: string,
  ~exitCode: option<int>,
  ~stderr: string,
  ~message: string,
  ~targetPath: string,
): backendError => {
  {
    backend,
    command,
    cwd,
    exitCode,
    stderr,
    message,
    targetPath,
  }
}

let formatBackendError = (err: backendError): string => {
  `search_files backend failure (${err.backend})
command: ${err.command}
cwd: ${err.cwd}
exit_code: ${formatExitCode(err.exitCode)}
stderr: ${trimForError(err.stderr)}
message: ${trimForError(err.message)}
target_path: ${err.targetPath}`
}

let formatFallbackError = (~firstError: backendError, ~secondError: backendError): string => {
  `search_files failed in both backends.

primary:
${formatBackendError(firstError)}

fallback:
${formatBackendError(secondError)}`
}

// Execute ripgrep for file search using spawn (no shell)
let executeRipgrep = async (
  ~rgPath: string,
  ~pattern: string,
  ~searchPath: string,
  ~maxResults: int,
): result<output, backendError> => {
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
  | Error({code, stderr, message, _}) =>
    Error(
      makeBackendError(
        ~backend="ripgrep",
        ~command=rgPath ++ " --files --hidden --no-ignore " ++ searchPath,
        ~cwd=searchPath,
        ~exitCode=code,
        ~stderr,
        ~message,
        ~targetPath=searchPath,
      ),
    )
  }
}

// Execute git ls-files using spawn (no shell) and filter results in-process.
// The old approach piped through `grep -i` via a shell string, which broke on
// patterns containing spaces or special characters.
let executeGitLsFiles = async (~pattern: string, ~searchPath: string, ~maxResults: int): result<
  output,
  backendError,
> => {
  let result = await ChildProcess.spawnResult("git", ["ls-files"], ~cwd=searchPath)

  switch result {
  | Ok({stdout}) => {
      let lines = stdout->String.trim->String.split("\n")->Array.filter(line => line !== "")
      Ok(filterAndPaginate(lines, ~pattern, ~maxResults))
    }
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalResults: 0, truncated: false})
  | Error({code, stderr, message, _}) =>
    Error(
      makeBackendError(
        ~backend="git",
        ~command="git ls-files",
        ~cwd=searchPath,
        ~exitCode=code,
        ~stderr,
        ~message,
        ~targetPath=searchPath,
      ),
    )
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  // resolveSearchDir ensures we always get a directory, even if the agent
  // passes a file path (e.g. "src/Button.tsx" → "src/").
  let requestedSearchPath = await PathContext.resolveSearchDir(
    ~sourceRoot=ctx.sourceRoot,
    ~inputPath=input.path,
  )

  let searchPath = switch await PathRecovery.nearestExistingDir(
    ~sourceRoot=ctx.sourceRoot,
    ~startPath=requestedSearchPath,
  ) {
  | Some(existingDir) => existingDir
  | None => ctx.sourceRoot
  }

  let maxResults = input.maxResults->Option.getOr(20)

  // Try ripgrep first, fall back to git ls-files
  let result = switch getRipgrepPath() {
  | Some(rgPath) =>
    let ripgrepResult = await executeRipgrep(
      ~rgPath,
      ~pattern=input.pattern,
      ~searchPath,
      ~maxResults,
    )

    switch ripgrepResult {
    | Ok(output) => Ok(output)
    | Error(ripgrepError) =>
      // Fallback to git ls-files
      switch await executeGitLsFiles(~pattern=input.pattern, ~searchPath, ~maxResults) {
      | Ok(output) => Ok(output)
      | Error(gitError) =>
        Error(formatFallbackError(~firstError=ripgrepError, ~secondError=gitError))
      }
    }
  | None =>
    // No ripgrep, use git ls-files
    switch await executeGitLsFiles(~pattern=input.pattern, ~searchPath, ~maxResults) {
    | Ok(output) => Ok(output)
    | Error(gitError) => Error(formatBackendError(gitError))
    }
  }

  switch result {
  | Ok(output) =>
    ToolPathHints.recordSearch(
      ~sourceRoot=ctx.sourceRoot,
      ~searchPath,
      ~pattern=input.pattern,
      ~files=output.files,
      ~totalResults=output.totalResults,
    )
    Ok(output)
  | Error(_) as err => err
  }
}
