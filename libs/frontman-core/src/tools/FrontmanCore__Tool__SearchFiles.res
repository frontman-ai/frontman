// SearchFiles tool - fast file/directory name search using ripgrep with git ls-files fallback

module Path = FrontmanBindings.Path
module ChildProcess = FrontmanBindings.ChildProcess
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = "search_files"
let visibleToAgent = true
let description = `Fast file and directory name search tool that finds files/directories matching a pattern.

WHEN TO USE THIS TOOL:
- Use when you need to find files or directories by name pattern
- Great for locating specific files like "config.json" or "*.test.ts"
- Useful for finding all files with a specific extension or naming convention
- When you need to discover the file structure of a project

PARAMETERS:
- pattern (required): The filename pattern to search for (supports glob-like patterns)
- path (optional): Directory to search in (defaults to source root)
- type (optional): Filter by type - "file" for files only, "directory" for directories only
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Find all config files: pattern="config"
- Find TypeScript test files: pattern="*.test.ts"
- Find directories named "components": pattern="components", type="directory"
- Find files in specific directory: pattern="*.json", path="src/config"

OUTPUT:
Returns list of matching file/directory paths.
Results are sorted by modification time (newest first).

LIMITATIONS:
- Results limited to max_results (default 20)
- Hidden files (starting with '.') are included
- Respects .gitignore when using git ls-files fallback`

@schema
type input = {
  pattern: string,
  path?: string,
  @as("type") type_?: string,
  @as("max_results") @s.default(20) maxResults?: int,
}

@schema
type output = {
  files: array<string>,
  totalResults: int,
  truncated: bool,
}

// Get ripgrep path from vscode-ripgrep package
let getRipgrepPath = (): option<string> => {
  try {
    let vsCodeRipgrep = %raw(`require('vscode-ripgrep')`)
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

// Parse ripgrep file list output and filter by pattern and type
let parseRipgrepOutput = (
  output: string,
  ~pattern: string,
  ~type_: option<string>,
  ~maxResults: int,
): output => {
  let lines = output->String.trim->String.split("\n")->Array.filter(line => line !== "")

  // Filter lines by pattern (case-insensitive glob-like matching)
  let patternLower = pattern->String.toLowerCase
  let matchedFiles = lines->Array.filter(filePath => {
    let fileName = Path.basename(filePath)->String.toLowerCase
    
    // Simple glob pattern matching
    let patternMatches = if patternLower === "" {
      // Empty pattern matches all
      true
    } else if patternLower->String.includes("*") {
      // Convert glob to regex-like matching
      let parts = patternLower->String.split("*")
      let partsLength = Array.length(parts)
      
      parts->Array.reduceWithIndex(true, (matches, part, idx) => {
        if !matches {
          false
        } else if part === "" {
          true
        } else if idx === 0 {
          fileName->String.startsWith(part)
        } else if idx === partsLength - 1 {
          fileName->String.endsWith(part)
        } else {
          fileName->String.includes(part)
        }
      })
    } else {
      // Simple substring match
      fileName->String.includes(patternLower)
    }

    // Type filter (note: ripgrep lists directories with trailing slashes on some systems)
    let typeMatches = switch type_ {
    | Some("file") => !(filePath->String.endsWith("/"))
    | Some("directory") => filePath->String.endsWith("/")
    | _ => true
    }

    patternMatches && typeMatches
  })

  let truncated = Array.length(matchedFiles) > maxResults
  let files = matchedFiles->Array.slice(~start=0, ~end=maxResults)

  {
    files,
    totalResults: Array.length(matchedFiles),
    truncated,
  }
}

// Parse git ls-files output
let parseGitLsFilesOutput = (output: string, ~maxResults: int): output => {
  let lines = output->String.trim->String.split("\n")->Array.filter(line => line !== "")

  let truncated = Array.length(lines) > maxResults
  let files = lines->Array.slice(~start=0, ~end=maxResults)

  {
    files,
    totalResults: Array.length(lines),
    truncated,
  }
}

// Execute ripgrep for file search
let executeRipgrep = async (
  ~rgPath: string,
  ~pattern: string,
  ~searchPath: string,
  ~type_: option<string>,
  ~maxResults: int,
): result<output, string> => {
  let args = buildRipgrepArgs(~searchPath)
  let command = `${rgPath} ${args->Array.join(" ")}`

  try {
    let result = await ChildProcess.exec(command)

    switch result {
    | Ok({stdout}) => Ok(parseRipgrepOutput(stdout, ~pattern, ~type_, ~maxResults))
    | Error({code: Some(1), _}) =>
      // Exit code 1 means no matches found
      Ok({files: [], totalResults: 0, truncated: false})
    | Error({stderr}) => Error(`Ripgrep failed: ${stderr}`)
    }
  } catch {
  | exn => {
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Ripgrep execution failed: ${msg}`)
    }
  }
}

// Execute git ls-files with grep as fallback
let executeGitLsFiles = async (
  ~pattern: string,
  ~searchPath: string,
  ~maxResults: int,
): result<output, string> => {
  try {
    let command = `git ls-files | grep -i "${pattern}"`
    let result = await ChildProcess.execWithOptions(command, {cwd: searchPath})

    switch result {
    | Ok({stdout}) => Ok(parseGitLsFilesOutput(stdout, ~maxResults))
    | Error({code: Some(1), _}) =>
      // Exit code 1 means no matches found
      Ok({files: [], totalResults: 0, truncated: false})
    | Error({stderr}) => Error(`Git ls-files failed: ${stderr}`)
    }
  } catch {
  | exn => {
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Git ls-files execution failed: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let searchPath = PathContext.resolveSearchPath(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path)
  let maxResults = input.maxResults->Option.getOr(100)

  // Try ripgrep first
  switch getRipgrepPath() {
  | Some(rgPath) =>
    let result = await executeRipgrep(
      ~rgPath,
      ~pattern=input.pattern,
      ~searchPath,
      ~type_=input.type_,
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

