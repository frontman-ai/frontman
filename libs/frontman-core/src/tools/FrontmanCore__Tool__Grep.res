module Path = FrontmanBindings.Path
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.grep
let access = Tool.Read
let description = `Searches **file contents** for text or regex patterns. Returns matching lines with file paths and line numbers.

Use grep to find where code is *used* — function calls, variable references, imports, error messages, string literals. If you need to find a file by *name* instead, use search_files.

PARAMETERS:
- pattern (required): Text or regex to search for inside files
- path (optional): Directory or file to search in (defaults to source root). When a file path is given, only that file is searched.
- type (optional): File type filter (e.g., "js", "ts", "py")
- glob (optional): Glob pattern to filter files (e.g., "*.tsx", "*.{ts,tsx}")
- case_insensitive (optional): Case insensitive search (default: false)
- literal (optional): Treat pattern as literal text, not regex (default: false)
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Find where useState is called: pattern="useState"
- Find API routes: pattern="app\\.(get|post|put)", glob="*.ts"
- Search within one file: pattern="className", path="src/components/Button.tsx"
- Literal dot search: pattern="console.log(", literal=true

OUTPUT:
Matching lines grouped by file, with line numbers. Sorted by file modification time (newest first).

LIMITATIONS:
- Results capped at max_results (default 20) files
- Binary files and hidden files (dotfiles) are skipped`

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
  @live
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

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

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

  args->Array.push("-n")
  args->Array.push("-H")

  switch caseInsensitive {
  | true => args->Array.push("-i")
  | false => ()
  }

  switch literal {
  | true => args->Array.push("-F")
  | false => ()
  }

  args->Array.push("-m")
  args->Array.push(Int.toString(maxResults))

  type_->Option.forEach(t => {
    args->Array.push("-t")
    args->Array.push(t)
  })

  glob->Option.forEach(g => {
    args->Array.push("--glob")
    args->Array.push(g)
  })

  args->Array.push(pattern)
  args->Array.push(searchPath)

  args
}

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

  args->Array.push("--max-count")
  args->Array.push(Int.toString(maxResults))

  args->Array.push(pattern)

  let hasPathspec = glob->Option.isSome || type_->Option.isSome
  switch hasPathspec {
  | true => {
      args->Array.push("--")

      switch glob {
      | Some(g) => args->Array.push(g)
      | None => ()
      }

      switch (type_, glob) {
      | (Some(t), None) => args->Array.push(`*.${t}`)
      | _ => ()
      }
    }
  | false => ()
  }

  args
}

let parseGrepOutput = (output: string, ~maxResults: int): output => {
  let lines = output->String.trim->String.split("\n")->Array.filter(line => line !== "")

  let fileMap = Dict.make()
  let totalMatches = ref(0)

  lines->Array.forEach(line => {
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

let executeRipgrep = async (
  ~rgPath: string,
  ~pattern: string,
  ~searchPath: string,
  ~type_: option<string>,
  ~glob: option<string>,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~signal: WebAPI.EventAPI.abortSignal,
): result<output, string> => {
  let args = buildRipgrepArgs(
    ~pattern,
    ~searchPath,
    ~type_,
    ~glob,
    ~caseInsensitive,
    ~literal,
    ~maxResults,
  )

  let result = await ChildProcess.spawnResult(rgPath, args, ~signal)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) => Ok({files: [], totalMatches: 0, truncated: false})
  | Error({stderr, message}) => {
      let detail = switch stderr {
      | "" => message
      | s => s
      }
      Error(`Ripgrep failed: ${detail}`)
    }
  }
}

let executeGitGrep = async (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
  ~signal: WebAPI.EventAPI.abortSignal,
): result<output, string> => {
  let args = buildGitGrepArgs(~pattern, ~caseInsensitive, ~literal, ~maxResults, ~glob, ~type_)

  let (cwd, filePathspec) = try {
    let stats = await FrontmanBindings.Fs.Promises.stat(searchPath)
    switch FrontmanBindings.Fs.isFile(stats) {
    | true => (Path.dirname(searchPath), Some(Path.basename(searchPath)))
    | false => (searchPath, None)
    }
  } catch {
  | _ => (searchPath, None)
  }

  switch filePathspec {
  | Some(file) =>
    switch args->Array.includes("--") {
    | true => args->Array.push(file)
    | false => {
        args->Array.push("--")
        args->Array.push(file)
      }
    }
  | None => ()
  }

  let result = await ChildProcess.spawnResult("git", args, ~cwd, ~signal)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) => Ok({files: [], totalMatches: 0, truncated: false})
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

  args->Array.push("-m")
  args->Array.push(Int.toString(maxResults))

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

  args->Array.push("--exclude-dir=node_modules")
  args->Array.push("--exclude-dir=.git")
  args->Array.push("--exclude-dir=dist")
  args->Array.push("--exclude-dir=build")
  args->Array.push("--exclude-dir=_build")

  args->Array.push(pattern)
  args->Array.push(searchPath)

  args
}

let executePlainGrep = async (
  ~pattern: string,
  ~searchPath: string,
  ~caseInsensitive: bool,
  ~literal: bool,
  ~maxResults: int,
  ~glob: option<string>,
  ~type_: option<string>,
  ~signal: WebAPI.EventAPI.abortSignal,
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

  let result = await ChildProcess.spawnResult("grep", args, ~signal)

  switch result {
  | Ok({stdout}) => Ok(parseGrepOutput(stdout, ~maxResults))
  | Error({code: Some(1), _}) => Ok({files: [], totalMatches: 0, truncated: false})
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

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  let searchPath = PathContext.resolveSearchPath(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path)
  let caseInsensitive = input.caseInsensitive->Option.getOr(false)
  let literal = input.literal->Option.getOr(false)
  let maxResults = input.maxResults->Option.getOr(20)

  let gitGrepWithFallback = async () => {
    let gitResult = await executeGitGrep(
      ~pattern=input.pattern,
      ~searchPath,
      ~caseInsensitive,
      ~literal,
      ~maxResults,
      ~glob=input.glob,
      ~type_=input.type_,
      ~signal=ctx.signal,
    )
    switch gitResult {
    | Ok(_) => gitResult
    | Error(_) =>
      await executePlainGrep(
        ~pattern=input.pattern,
        ~searchPath,
        ~caseInsensitive,
        ~literal,
        ~maxResults,
        ~glob=input.glob,
        ~type_=input.type_,
        ~signal=ctx.signal,
      )
    }
  }

  let result = switch await FrontmanBindings.Ripgrep.getRipgrepPath() {
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
      ~signal=ctx.signal,
    )

    switch result {
    | Ok(_) => result
    | Error(_) => await gitGrepWithFallback()
    }
  | None => await gitGrepWithFallback()
  }

  switch result {
  | Ok(output) => Tool.structuredResult(output, outputSchema)
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
