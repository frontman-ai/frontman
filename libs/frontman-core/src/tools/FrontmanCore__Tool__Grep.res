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
  switch caseInsensitive {
  | true => args->Array.push("-i")
  | false => ()
  }

  // Literal search (fixed strings)
  switch literal {
  | true => args->Array.push("-F")
  | false => ()
  }

  // Max count per file — ripgrep's -m flag limits matches per file, not globally.
  // parseGrepOutput handles the global cap by truncating to maxResults files.
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
// git grep supports pathspecs after `--` for file filtering, e.g.:
//   git grep -n "pattern" -- "*.astro"
let buildGitGrepArgs = (
  ~pattern: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
): array<string> => {
  let args = ["grep", "-n", "-H"]

  switch caseInsensitive {
  | true => args->Array.push("-i")
  | false => ()
  }

  switch literal {
  | true => args->Array.push("-F")
  | false => ()
  }

  // --max-count is per file for git grep, not a global limit.
  // parseGrepOutput handles the global cap by truncating to maxResults files.
  args->Array.push("--max-count")
  args->Array.push(Int.toString(maxResults))

  args->Array.push(pattern)

  // Add pathspec filters after `--` separator
  // git grep uses `--` to separate options from pathspecs
  let hasPathspec = glob->Option.isSome || type_->Option.isSome
  switch hasPathspec {
  | true => {
      args->Array.push("--")

      // Glob pattern takes precedence if provided
      switch glob {
      | Some(g) => args->Array.push(g)
      | None => ()
      }

      // Type filter: map common type names to glob patterns
      // Only apply if no explicit glob was given (glob is more specific)
      switch (type_, glob) {
      | (Some(t), None) => args->Array.push(`*.${t}`)
      | _ => ()
      }
    }
  | false => ()
  }

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
    switch colonIndex > 0 {
    | true => {
        let rest = line->String.substring(~start=colonIndex + 1)
        let secondColonIndex = rest->String.indexOf(":")

        switch secondColonIndex > 0 {
        | true => {
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
        | false => ()
        }
      }
    | false => ()
    }
  })

  // Convert to array of file matches, capped at maxResults files
  let allFiles =
    fileMap
    ->Dict.toArray
    ->Array.map(((path, matches)) => {path, matches})

  let totalFiles = allFiles->Array.length
  let files = allFiles->Array.slice(~start=0, ~end=maxResults)

  {
    files,
    totalMatches: totalMatches.contents,
    truncated: totalFiles > maxResults,
  }
}

// Execute ripgrep using spawn (no shell) to avoid argument splitting issues
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

  let result = await ChildProcess.spawnResult(rgPath, args)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalMatches: 0, truncated: false})
   | Error({stderr, message}) => {
       let detail = switch stderr {
        | "" => message
        | s => s
        }
      Error(`Ripgrep failed: ${detail}`)
    }
  }
}

// Execute git grep as fallback using spawn (no shell) to avoid argument splitting issues
let executeGitGrep = async (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
): result<output, string> => {
  let args = buildGitGrepArgs(~pattern, ~caseInsensitive, ~literal, ~maxResults, ~glob, ~type_)

  let result = await ChildProcess.spawnResult("git", args, ~cwd=searchPath)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalMatches: 0, truncated: false})
  | Error({code, stderr, message}) => {
      let codeStr = code->Option.map(c => Int.toString(c))->Option.getOr("unknown")
      let detail = switch stderr {
      | "" => message
      | s => s
      }
      Error(`Git grep failed (exit ${codeStr}): ${detail}`)
    }
  }
}

// Build plain grep arguments as a last-resort fallback when both ripgrep and git grep fail.
// Uses grep -rn which is available on virtually all Unix-like systems.
let buildPlainGrepArgs = (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
): array<string> => {
  let args = ["-rn"]

  switch caseInsensitive {
  | true => args->Array.push("-i")
  | false => ()
  }

  switch literal {
  | true => args->Array.push("-F")
  | false => ()
  }

  // -m is per file for plain grep, not a global limit.
  // parseGrepOutput handles the global cap by truncating to maxResults files.
  args->Array.push("-m")
  args->Array.push(Int.toString(maxResults))

  // File inclusion patterns
  switch glob {
  | Some(g) => {
      args->Array.push("--include")
      args->Array.push(g)
    }
  | None =>
    switch type_ {
    | Some(t) => {
        args->Array.push("--include")
        args->Array.push(`*.${t}`)
      }
    | None => ()
    }
  }

  // Exclude common noisy directories
  args->Array.push("--exclude-dir=node_modules")
  args->Array.push("--exclude-dir=.git")
  args->Array.push("--exclude-dir=dist")
  args->Array.push("--exclude-dir=build")
  args->Array.push("--exclude-dir=_build")

  args->Array.push(pattern)
  args->Array.push(searchPath)

  args
}

// Execute plain grep -rn as last-resort fallback
let executePlainGrep = async (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
): result<output, string> => {
  let args = buildPlainGrepArgs(
    ~pattern,
    ~searchPath,
    ~caseInsensitive,
    ~literal,
    ~maxResults,
    ~glob,
    ~type_,
  )

  let result = await ChildProcess.spawnResult("grep", args)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) =>
    // Exit code 1 means no matches found
    Ok({files: [], totalMatches: 0, truncated: false})
  | Error({code, stderr, message}) => {
      let codeStr = code->Option.map(c => Int.toString(c))->Option.getOr("unknown")
      let detail = switch stderr {
      | "" => message
      | s => s
      }
      Error(`Grep failed (exit ${codeStr}): ${detail}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let searchPath = PathContext.resolveSearchPath(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path)
  let caseInsensitive = input.caseInsensitive->Option.getOr(false)
  let literal = input.literal->Option.getOr(false)
  let maxResults = input.maxResults->Option.getOr(20)

  // Shared fallback chain: git grep -> plain grep
  let gitGrepWithFallback = async () => {
    let gitResult = await executeGitGrep(
      ~pattern=input.pattern,
      ~searchPath,
      ~caseInsensitive,
      ~literal,
      ~maxResults,
      ~glob=input.glob,
      ~type_=input.type_,
    )
    switch gitResult {
    | Ok(_) => gitResult
    | Error(_) =>
      // git grep failed (not a git repo, etc.) - fall back to plain grep
      await executePlainGrep(
        ~pattern=input.pattern,
        ~searchPath,
        ~caseInsensitive,
        ~literal,
        ~maxResults,
        ~glob=input.glob,
        ~type_=input.type_,
      )
    }
  }

  // Try ripgrep first, then git grep, then plain grep
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
    | Error(_) => await gitGrepWithFallback()
    }
  | None => await gitGrepWithFallback()
  }
}

