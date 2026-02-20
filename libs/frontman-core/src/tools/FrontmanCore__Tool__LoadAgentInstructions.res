// Load agent instructions tool - discovers and loads Agents.md or CLAUDE.md files

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module SafePath = FrontmanCore__SafePath

let name = Tool.ToolNames.loadAgentInstructions
let visibleToAgent = false
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

// File variants to check at each directory level
let agentsVariants = ["Agents.md", ".claude/Agents.md", "Agents.local.md"]
let claudeVariants = ["CLAUDE.md", ".claude/CLAUDE.md", "CLAUDE.local.md"]

// Check if a file exists
let fileExists = async (path: string): bool => {
  try {
    await Fs.Promises.access(path)
    true
  } catch {
  | _ => false
  }
}

// Find a file case-insensitively in a directory (directory path is case-sensitive, only filename is case-insensitive)
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

// Load a single file if it exists (case-insensitive filename matching)
let loadIfExists = async (path: string): option<instructionFile> => {
  // Directory path must be exact, only the filename is case-insensitive
  let dir = Path.dirname(path)
  let fileName = Path.basename(path)

  // Try to find the file case-insensitively in the directory
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

// Load all existing files from a list of variants in a directory
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

// Find all instruction files at a directory (Agents.md priority over CLAUDE.md)
let findAtDirectory = async (dir: string): array<instructionFile> => {
  // First try Agents variants
  let agentsFiles = await loadVariants(dir, agentsVariants)

  if Array.length(agentsFiles) > 0 {
    // Found Agents files - skip CLAUDE variants
    agentsFiles
  } else {
    // No Agents files - try CLAUDE variants
    await loadVariants(dir, claudeVariants)
  }
}

// Recursively walk up directories until root
let rec walkUpDirectories = async (current: string, acc: array<instructionFile>): array<
  instructionFile,
> => {
  if current == "/" {
    acc
  } else {
    let filesAtLevel = await findAtDirectory(current)
    let newAcc = Array.concat(acc, filesAtLevel)
    await walkUpDirectories(Path.dirname(current), newAcc)
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  // Validate startPath is under sourceRoot (prevents starting from arbitrary locations)
  let inputPath = input.startPath->Option.getOr(".")

  switch SafePath.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath) {
  | Error(msg) => Error(msg)
  | Ok(safePath) =>
    try {
      // Start from the validated path and walk up to find instruction files
      // Note: walkUpDirectories intentionally goes above sourceRoot - that's by design
      // for finding CLAUDE.md files in parent directories
      let startPath = SafePath.toString(safePath)
      let results = await walkUpDirectories(startPath, [])
      Ok(results)
    } catch {
    | exn =>
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to load agent instructions: ${msg}`)
    }
  }
}
