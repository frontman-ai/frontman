// Grep tool - fast content search using ripgrep with git grep fallback

module Path = FrontmanBindings.Path
module ChildProcess = FrontmanBindings.ChildProcess
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = "grep"
let visibleToAgent = true
let description = `Fast content search tool that finds files containing specific text or patterns, returning matching lines sorted by file modification time.

WHEN TO USE THIS TOOL:
- Use when you need to find files containing specific text or patterns
- Great for searching code bases for function names, variable declarations, or error messages
- Useful for finding all files that use a particular API or pattern

PARAMETERS:
- pattern (required): The text or regex pattern to search for
- path (optional): Directory to search in (defaults to source root)
- type (optional): File type filter (e.g., "js", "ts", "py", "go")
- glob (optional): Glob pattern to filter files (e.g., "*.js", "*.{ts,tsx}")
- case_insensitive (optional): Case insensitive search (default: false)
- literal (optional): Treat pattern as literal text, not regex (default: false)
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Find "function" in JavaScript files: pattern="function", type="js"
- Find imports: pattern="import.*from", glob="*.ts"
- Case-insensitive search: pattern="error", case_insensitive=true
- Literal search: pattern="log.error()", literal=true

OUTPUT:
Returns matching lines grouped by file, with line numbers and content.
Results are sorted by file modification time (newest first).

LIMITATIONS:
- Results limited to max_results (default 20)
- Binary files are automatically skipped
- Hidden files (starting with '.') are skipped by default`

@schema
type input = {
  pattern: string,
  path?: string,
  @as("type") type_?: string,
  glob?: string,
  @as("case_insensitive") caseInsensitive?: bool,
  literal?: bool,
  @as("max_results") @s.default(20) maxResults?: int,
}

@schema
type matchLine = {
  lineNum: int,
  lineText: string,
}

@schema
type fileMatch = {
  path: string,
  matches: array<matchLine>,
}

@schema
type output = {
  files: array<fileMatch>,
  totalMatches: int,
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

// Build ripgrep arguments
let buildRipgrepArgs = (
  ~pattern: string,
  ~searchPath: string,
  ~type_: option<string>,
  ~glob: option<string>,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
): array<string> => {
  let args = []

  // Line numbers and column format
  args->Array.push("-n")
  args->Array.push("-H")

  // Case insensitive
  if caseInsensitive {
    args->Array.push("-i")
  }

  // Literal search (fixed strings)
  if literal {
    args->Array.push("-F")
  }

  // Max count
  args->Array.push("-m")
  args->Array.push(Int.toString(maxResults))

  // File type
  type_->Option.forEach(t => {
    args->Array.push("-t")
    args->Array.push(t)
  })

  // Glob pattern
  glob->Option.forEach(g => {
    args->Array.push("--glob")
    args->Array.push(g)
  })

  // Pattern and path
  args->Array.push(pattern)
  args->Array.push(searchPath)

  args
}

// Build git grep arguments
let buildGitGrepArgs = (
  ~pattern: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
): array<string> => {
  let args = ["grep", "-n", "-H"]

  if caseInsensitive {
    args->Array.push("-i")
  }

  if literal {
    args->Array.push("-F")
  }

  args->Array.push("--max-count")
  args->Array.push(Int.toString(maxResults))

  args->Array.push(pattern)

  args
}

// Parse ripgrep/git grep output
let parseGrepOutput = (output: string, ~maxResults: int): output => {
  let lines = output->String.trim->String.split("\n")->Array.filter(line => line !== "")

  // Group by file
  let fileMap = Dict.make()
  let totalMatches = ref(0)

  lines->Array.forEach(line => {
    // Format: filepath:linenum:content
    let colonIndex = line->String.indexOf(":")
    if colonIndex > 0 {
      let rest = line->String.substring(~start=colonIndex + 1)
      let secondColonIndex = rest->String.indexOf(":")

      if secondColonIndex > 0 {
        let filePath = line->String.substring(~start=0, ~end=colonIndex)
        let lineNumStr = rest->String.substring(~start=0, ~end=secondColonIndex)
        let lineText = rest->String.substring(~start=secondColonIndex + 1)

        switch Int.fromString(lineNumStr) {
        | Some(lineNum) => {
            totalMatches := totalMatches.contents + 1

            let matches = switch fileMap->Dict.get(filePath) {
            | Some(existing) => existing
            | None => []
            }

            matches->Array.push({lineNum, lineText})
            fileMap->Dict.set(filePath, matches)
          }
        | None => ()
        }
      }
    }
  })

  // Convert to array of file matches
  let files =
    fileMap
    ->Dict.toArray
    ->Array.map(((path, matches)) => {path, matches})
    ->Array.slice(~start=0, ~end=maxResults)

  {
    files,
    totalMatches: totalMatches.contents,
    truncated: totalMatches.contents > maxResults,
  }
}

// Execute ripgrep
let executeRipgrep = async (
  ~rgPath: string,
  ~pattern: string,
  ~searchPath: string,
  ~type_: option<string>,
  ~glob: option<string>,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
): result<output, string> => {
  let args = buildRipgrepArgs(~pattern, ~searchPath, ~type_, ~glob, ~caseInsensitive, ~literal, ~maxResults)
  let command = `${rgPath} ${args->Array.join(" ")}`

  try {
    let result = await ChildProcess.exec(command)

    switch result {
    | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
    | Error({code: Some(1), _}) =>
      // Exit code 1 means no matches found
      Ok({files: [], totalMatches: 0, truncated: false})
    | Error({stderr}) => Error(`Ripgrep failed: ${stderr}`)
    }
  } catch {
  | exn => {
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Ripgrep execution failed: ${msg}`)
    }
  }
}

// Execute git grep as fallback
let executeGitGrep = async (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
): result<output, string> => {
  let args = buildGitGrepArgs(~pattern, ~caseInsensitive, ~literal, ~maxResults)

  try {
    let result = await ChildProcess.execWithOptions(
      `git ${args->Array.join(" ")}`,
      {cwd: searchPath},
    )

    switch result {
    | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
    | Error({code: Some(1), _}) =>
      // Exit code 1 means no matches found
      Ok({files: [], totalMatches: 0, truncated: false})
    | Error({stderr}) => Error(`Git grep failed: ${stderr}`)
    }
  } catch {
  | exn => {
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Git grep execution failed: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let searchPath = PathContext.resolveSearchPath(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path)
  let caseInsensitive = input.caseInsensitive->Option.getOr(false)
  let literal = input.literal->Option.getOr(false)
  let maxResults = input.maxResults->Option.getOr(100)

  // Try ripgrep first
  switch getRipgrepPath() {
  | Some(rgPath) =>
    let result = await executeRipgrep(
      ~rgPath,
      ~pattern=input.pattern,
      ~searchPath,
      ~type_=input.type_,
      ~glob=input.glob,
      ~caseInsensitive,
      ~literal,
      ~maxResults,
    )

    switch result {
    | Ok(_) => result
    | Error(_) =>
      // Fallback to git grep
      await executeGitGrep(~pattern=input.pattern, ~searchPath, ~caseInsensitive, ~literal, ~maxResults)
    }
  | None =>
    // No ripgrep, use git grep
    await executeGitGrep(~pattern=input.pattern, ~searchPath, ~caseInsensitive, ~literal, ~maxResults)
  }
}

