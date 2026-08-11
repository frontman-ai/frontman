module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath

let name = Tool.ToolNames.loadAgentInstructions
let access = Tool.Read
let description = `Discovers and loads agent instruction files (Agents.md or CLAUDE.md) following Claude Code's discovery algorithm.

Parameters:
- startPath (optional): Starting directory for discovery - must be under source root. Defaults to "." (source root).

Discovery:
- Walks up from startPath to filesystem root
- At each level, checks for Agents.md variants (Agents.md, .claude/Agents.md, Agents.local.md)
- If any Agents variant found at a level, skips CLAUDE variants for that level
- Otherwise checks CLAUDE variants (CLAUDE.md, .claude/CLAUDE.md, CLAUDE.local.md)
- All matching files at each level are included
- Returns all found instruction files`

@schema
type input = {startPath?: string}

@schema
type instructionFile = {
  content: string,
  fullPath: string,
}

@schema
type output = array<instructionFile>

let (visibleToAgent, outputJsonSchema) = (false, None)

let agentsVariants = ["Agents.md", ".claude/Agents.md", "Agents.local.md"]
let claudeVariants = ["CLAUDE.md", ".claude/CLAUDE.md", "CLAUDE.local.md"]

let findFileCaseInsensitive = async (dir: string, targetFileName: string): option<string> => {
  try {
    let files = await Fs.Promises.readdir(dir)
    let targetLower = String.toLowerCase(targetFileName)

    let found = files->Array.find(file => String.toLowerCase(file) == targetLower)

    switch found {
    | Some(actualFileName) => Some(Path.join([dir, actualFileName]))
    | None => None
    }
  } catch {
  | _ => None
  }
}

let loadIfExists = async (path: string): option<instructionFile> => {
  let dir = Path.dirname(path)
  let fileName = Path.basename(path)

  let actualPath = await findFileCaseInsensitive(dir, fileName)

  switch actualPath {
  | Some(foundPath) =>
    try {
      let content = await Fs.Promises.readFile(foundPath)
      Some({content, fullPath: foundPath})
    } catch {
    | _ => None
    }
  | None => None
  }
}

let loadVariants = async (dir: string, variants: array<string>): array<instructionFile> => {
  let results = []
  for i in 0 to Array.length(variants) - 1 {
    let variant = variants->Array.getUnsafe(i)
    let path = Path.join([dir, variant])
    switch await loadIfExists(path) {
    | Some(file) => results->Array.push(file)->ignore
    | None => ()
    }
  }
  results
}

let findAtDirectory = async (dir: string): array<instructionFile> => {
  let agentsFiles = await loadVariants(dir, agentsVariants)

  if Array.length(agentsFiles) > 0 {
    agentsFiles
  } else {
    await loadVariants(dir, claudeVariants)
  }
}

let rec walkUpDirectories = async (current: string, acc: array<instructionFile>): array<
  instructionFile,
> => {
  let parent = Path.dirname(current)
  if parent == current {
    acc
  } else {
    let filesAtLevel = await findAtDirectory(current)
    let newAcc = Array.concat(acc, filesAtLevel)
    await walkUpDirectories(parent, newAcc)
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  let inputPath = input.startPath->Option.getOr(".")

  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath) {
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  | Ok(safePath) =>
    try {
      let startPath = SafePath.toString(safePath)
      let results = await walkUpDirectories(startPath, [])
      Tool.unstructuredResult(results, outputSchema)
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Tool.MCP.CallToolResult.makeError(`Failed to load agent instructions: ${msg}`)
    }
  }
}
