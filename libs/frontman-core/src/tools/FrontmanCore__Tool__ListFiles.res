module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module ToolPathHints = FrontmanCore__ToolPathHints

let name = Tool.ToolNames.listFiles
let access = Tool.Read
let description = `Lists the **immediate contents** of a single directory — names, paths, and whether each entry is a file or directory.

Use list_files to inspect one directory before reading or editing files. For a recursive multi-level tree, use list_tree instead. To find files by name across the project, use search_files.

PARAMETERS:
- path (optional): Directory to list (relative to source root or absolute). Defaults to "." (project root). If a file path is given, lists its parent directory.

OUTPUT:
Array of entries, each with name, path, isFile, and isDirectory. Respects .gitignore when Git is available in a repository. Otherwise lists filesystem entries with a fallback notice; ignore filtering is not applied.`

@schema
type input = {path?: string}

@schema
type fileEntry = {
  name: string,
  path: string,
  isFile: bool,
  isDirectory: bool,
}

@schema
type output = array<fileEntry>

let (visibleToAgent, outputJsonSchema) = (true, None)

let getIgnoredEntries = async (
  ~cwd: string,
  ~onFallback: string => unit=_ => (),
  entries: array<string>,
): result<array<string>, string> => {
  if Array.length(entries) == 0 {
    Ok([])
  } else {
    try {
      let args =
        entries
        ->Array.map(entry => "'" ++ entry->String.replaceAll("'", "'\\''") ++ "'")
        ->Array.join(" ")
      let result = await ChildProcess.execWithOptions(
        `printf '%s\\0' ${args} | git check-ignore -z --stdin`,
        {cwd: cwd},
      )

      switch result {
      | Ok({stdout}) => Ok(stdout->String.split("\x00")->Array.filter(s => s !== ""))
      | Error({code: Some(1), _}) => Ok([])
      | Error({code, stderr, message})
        if code == Some(127) ||
        stderr->String.includes("not a git repository") ||
        message->String.includes("ENOENT") =>
        onFallback(
          "[filesystem fallback] Git is unavailable or this directory is not a repository; .gitignore filtering was not applied.",
        )
        Ok([])
      | Error({stderr, message}) => Error(`git check-ignore failed: ${stderr} ${message}`)
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`git check-ignore error: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  let path = input.path->Option.getOr(".")

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=path) {
  | Error(err) => Tool.MCP.CallToolResult.makeError(PathContext.formatError(err))
  | Ok(result) =>
    try {
      let (fullPath, relativePath) = try {
        let stats = await Fs.Promises.stat(result.resolvedPath)
        switch Fs.isFile(stats) {
        | true => (Path.dirname(result.resolvedPath), Path.dirname(path))
        | false => (result.resolvedPath, path)
        }
      } catch {
      | _ => (result.resolvedPath, path)
      }
      let entries = await Fs.Promises.readdir(fullPath)

      let notice = ref(None)
      let filteredEntriesResult =
        (
          await getIgnoredEntries(~cwd=fullPath, ~onFallback=msg => notice := Some(msg), entries)
        )->Result.map(ignored => entries->Array.filter(name => !(ignored->Array.includes(name))))

      switch filteredEntriesResult {
      | Error(msg) =>
        Tool.MCP.CallToolResult.makeError(
          `${msg} (requested: ${path}, sourceRoot: ${ctx.sourceRoot}, resolved: ${fullPath})`,
        )
      | Ok(filteredEntries) =>
        let entriesWithStats = await filteredEntries
        ->Array.map(async name => {
          let entryPath = Path.join([fullPath, name])
          let stats = await Fs.Promises.stat(entryPath)

          {
            name,
            path: Path.join([relativePath, name]),
            isFile: Fs.isFile(stats),
            isDirectory: Fs.isDirectory(stats),
          }
        })
        ->Promise.all

        ToolPathHints.recordListAnchor(~sourceRoot=ctx.sourceRoot, ~path=relativePath)

        switch notice.contents {
        | None => Tool.unstructuredResult(entriesWithStats, outputSchema)
        | Some(msg) =>
          Tool.textResult(
            msg ++
            "\n" ++
            entriesWithStats
            ->S.decodeOrThrow(~from=outputSchema, ~to=S.json->S.noValidation(true))
            ->JSON.stringify,
          )
        }
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Tool.MCP.CallToolResult.makeError(
        `Failed to list files in ${path} (sourceRoot: ${ctx.sourceRoot}, resolved: ${result.resolvedPath}): ${msg}`,
      )
    }
  }
}
