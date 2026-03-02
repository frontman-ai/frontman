// List files tool - lists directory contents

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = Tool.ToolNames.listFiles
let visibleToAgent = true
let description = `Lists the **immediate contents** of a single directory — names, paths, and whether each entry is a file or directory.

Use list_files to inspect one directory before reading or editing files. For a recursive multi-level tree, use list_tree instead. To find files by name across the project, use search_files.

PARAMETERS:
- path (optional): Directory to list (relative to source root or absolute). Defaults to "." (project root). If a file path is given, lists its parent directory.

OUTPUT:
Array of entries, each with name, path, isFile, and isDirectory. Respects .gitignore — ignored entries are excluded.`

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

// Get entries that are ignored by git (respects .gitignore)
let getIgnoredEntries = async (~cwd: string, entries: array<string>): result<
  array<string>,
  string,
> => {
  if Array.length(entries) == 0 {
    Ok([])
  } else {
    try {
      let entriesArg = entries->Array.join("\n")
      let command = `printf "%s" "${entriesArg}" | git check-ignore --stdin`
      let result = await ChildProcess.execWithOptions(command, {cwd: cwd})

      switch result {
      | Ok({stdout}) => Ok(stdout->String.trim->String.split("\n")->Array.filter(s => s !== ""))
      | Error({code: Some(1), _}) => Ok([]) // Exit code 1 = no files ignored
      | Error({code: Some(128), stderr}) => Error(`Not a git repository: ${stderr}`)
      | Error({stderr}) => Error(`git check-ignore failed: ${stderr}`)
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`git check-ignore error: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let path = input.path->Option.getOr(".")

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    try {
      // If the agent passed a file path, use its parent directory instead.
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

      let filteredEntriesResult =
        (await getIgnoredEntries(~cwd=fullPath, entries))->Result.map(ignored =>
          entries->Array.filter(name => !(ignored->Array.includes(name)))
        )

      switch filteredEntriesResult {
      | Error(msg) => Error(msg)
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

        Ok(entriesWithStats)
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to list files in ${path}: ${msg}`)
    }
  }
}
