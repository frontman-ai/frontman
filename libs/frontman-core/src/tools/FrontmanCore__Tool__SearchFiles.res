module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module PathRecovery = FrontmanCore__PathRecovery
module ToolPathHints = FrontmanCore__ToolPathHints
module FilenamePattern = FrontmanCore__FilenamePattern

let name = Tool.ToolNames.searchFiles
let access = Tool.Read
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

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

type backendError = {
  backend: string,
  command: string,
  cwd: string,
  exitCode: option<int>,
  stderr: string,
  message: string,
  targetPath: string,
}

let buildRipgrepArgs = (~searchPath: string): array<string> => {
  let args = []

  args->Array.push("--files")

  args->Array.push("--hidden")

  args->Array.push("--no-ignore")

  args->Array.push(searchPath)

  args
}

let matchesPattern = (fileName: string, ~patternLower: string): bool =>
  FilenamePattern.matchesPattern(~pattern=patternLower, ~text=fileName)

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
  | Error({code: Some(1), _}) => Ok({files: [], totalResults: 0, truncated: false})
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
  | Error({code: Some(1), _}) => Ok({files: [], totalResults: 0, truncated: false})
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

let executeOutput = async (ctx: Tool.serverExecutionContext, input: input): result<
  output,
  string,
> => {
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

  let result = switch await FrontmanBindings.Ripgrep.getRipgrepPath() {
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
      switch await executeGitLsFiles(~pattern=input.pattern, ~searchPath, ~maxResults) {
      | Ok(output) => Ok(output)
      | Error(gitError) =>
        Error(formatFallbackError(~firstError=ripgrepError, ~secondError=gitError))
      }
    }
  | None =>
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

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await executeOutput(ctx, input) {
  | Ok(output) => Tool.structuredResult(output, outputSchema)
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
