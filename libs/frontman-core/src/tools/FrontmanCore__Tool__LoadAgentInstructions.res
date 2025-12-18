// Load agent instructions tool - discovers and loads Agents.md or CLAUDE.md files

module Path = AskTheLlmBindings.Path
module Fs = AskTheLlmBindings.Fs
module Tool = AskTheLlmFrontmanProtocol.FrontmanProtocol__Tool

let name = "load_agent_instructions"
let visibleToAgent = false
let description = `Discovers and loads agent instruction files (Agents.md or CLAUDE.md) following Claude Code's discovery algorithm.

Parameters:
- startPath (optional): Starting directory for discovery. Defaults to "." (source root).

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

// Load a single file if it exists
let loadIfExists = async (path: string): option<instructionFile> => {
  if await fileExists(path) {
    try {
      let content = await Fs.Promises.readFile(path)
      Some({content, fullPath: path})
    } catch {
    | _ => None
    }
  } else {
    None
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

// Resolve start path to absolute path
let resolveStartPath = (sourceRoot: string, startPath: option<string>): string => {
  switch startPath {
  | Some(p) => Path.resolve(Path.join([sourceRoot, p]))
  | None => Path.resolve(sourceRoot)
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
  try {
    let startPath = resolveStartPath(ctx.sourceRoot, input.startPath)
    let results = await walkUpDirectories(startPath, [])
    Ok(results)
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to load agent instructions: ${msg}`)
  }
}
