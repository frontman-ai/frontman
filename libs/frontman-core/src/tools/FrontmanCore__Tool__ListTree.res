// ListTree tool - project directory tree with monorepo workspace detection
//
// Dual-purpose: called implicitly during MCP init for project overview,
// and available to the agent for on-demand deeper exploration.

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FsUtils = FrontmanCore__FsUtils

let name = Tool.ToolNames.listTree
let visibleToAgent = true
let description = `Returns a **recursive directory tree** of the project structure, with monorepo workspace detection.

Use list_tree to get oriented in a codebase, understand the layout, or explore a subtree. Prefer this over chaining multiple list_files calls. For a flat listing of one directory, use list_files instead.

PARAMETERS:
- path (optional): Subdirectory to root the tree at. Defaults to "." (project root). If a file path is given, shows the tree from its parent directory.
- depth (optional): Maximum directory depth to display. Defaults to 3.

OUTPUT:
Text tree with directories (ending in /) and files. Workspace roots are annotated with [workspace: name]. Respects .gitignore. Skips node_modules, .git, dist, build, etc.`

@schema
type input = {
  path?: string,
  @s.default(3) depth?: int,
}

@schema
type workspace = {
  name: string,
  path: string,
}

@schema
type output = {
  tree: string,
  workspaces: array<workspace>,
  monorepoType: option<string>,
}

// Sury schemas for parsing package.json fields
@schema
type packageJsonName = {
  name?: string,
}

@schema
type packageJsonWorkspacesObj = {
  packages?: array<string>,
}

// Directories to always skip in the tree output
let noiseDirs = [
  "node_modules",
  ".git",
  "dist",
  "build",
  ".next",
  "_build",
  "deps",
  ".turbo",
  ".cache",
  "coverage",
  ".svelte-kit",
  ".output",
  ".nuxt",
  ".vercel",
  "__pycache__",
  "target",
]

let isNoiseDir = (name: string): bool => noiseDirs->Array.includes(name)

// Max entries at any level before truncation
let maxEntriesPerLevel = 15
let showEntriesBeforeTruncation = 10

type rec trieNode = {
  name: string,
  children: ref<Dict.t<trieNode>>,
  isFile: ref<bool>,
}

let makeTrieNode = (name: string): trieNode => {
  name,
  children: ref(Dict.make()),
  isFile: ref(false),
}

let buildTrie = (files: array<string>): trieNode => {
  let root = makeTrieNode(".")

  files->Array.forEach(filePath => {
    let parts = filePath->String.split("/")->Array.filter(p => p !== "")
    let current = ref(root)

    parts->Array.forEachWithIndex((part, idx) => {
      let isLast = idx == Array.length(parts) - 1

      switch current.contents.children.contents->Dict.get(part) {
      | Some(existing) =>
        switch isLast {
        | true => existing.isFile := true
        | false => ()
        }
        current := existing
      | None =>
        let node = makeTrieNode(part)
        switch isLast {
        | true => node.isFile := true
        | false => ()
        }
        current.contents.children.contents->Dict.set(part, node)
        current := node
      }
    })
  })

  root
}

type sortedEntry = {
  entryName: string,
  node: trieNode,
  isDir: bool,
}

let getSortedChildren = (node: trieNode): array<sortedEntry> => {
  let entries =
    node.children.contents
    ->Dict.toArray
    ->Array.map(((entryName, child)) => {
      let hasChildren = child.children.contents->Dict.keysToArray->Array.length > 0
      let isDir = hasChildren || !child.isFile.contents
      {entryName, node: child, isDir}
    })
    ->Array.filter(e => !isNoiseDir(e.entryName))

  // Sort: directories first, then files, alphabetical within each group
  entries->Array.toSorted((a, b) => {
    switch (a.isDir, b.isDir) {
    | (true, false) => -1.0
    | (false, true) => 1.0
    | _ =>
      switch String.compare(a.entryName, b.entryName) {
      | n if n < 0.0 => -1.0
      | n if n > 0.0 => 1.0
      | _ => 0.0
      }
    }
  })
}

let renderTree = (
  root: trieNode,
  ~maxDepth: int,
  ~workspacePaths: Dict.t<string>,
): string => {
  let lines: array<string> = []

  let rec walk = (node: trieNode, ~prefix: string, ~currentDepth: int, ~parentPath: option<string>) => {
    switch currentDepth > maxDepth {
    | true => ()
    | false =>
      let children = getSortedChildren(node)
      let totalCount = Array.length(children)
      let truncated = totalCount > maxEntriesPerLevel
      let visibleChildren = switch truncated {
      | true => children->Array.slice(~start=0, ~end=showEntriesBeforeTruncation)
      | false => children
      }
      let visibleCount = Array.length(visibleChildren)

      visibleChildren->Array.forEachWithIndex((entry, idx) => {
        let isLastVisible = idx == visibleCount - 1 && !truncated
        let connector = switch isLastVisible {
        | true => `└── `
        | false => `├── `
        }
        let childPrefix = switch isLastVisible {
        | true => prefix ++ "    "
        | false => prefix ++ `│   `
        }

        let suffix = switch entry.isDir {
        | true => "/"
        | false => ""
        }

        // Build the full relative path for this entry to match against workspace paths
        let entryRelPath = switch parentPath {
        | None => entry.entryName
        | Some(p) => p ++ "/" ++ entry.entryName
        }

        // Check if this directory is a workspace root
        let workspaceAnnotation = switch entry.isDir {
        | true =>
          switch workspacePaths->Dict.get(entryRelPath) {
          | Some(wsName) => ` [workspace: ${wsName}]`
          | None => ""
          }
        | false => ""
        }

        lines->Array.push(prefix ++ connector ++ entry.entryName ++ suffix ++ workspaceAnnotation)

        switch entry.isDir {
        | true =>
          walk(entry.node, ~prefix=childPrefix, ~currentDepth=currentDepth + 1, ~parentPath=Some(entryRelPath))
        | false => ()
        }
      })

      switch truncated {
      | true =>
        let remaining = totalCount - showEntriesBeforeTruncation
        lines->Array.push(prefix ++ `└── ... and ${Int.toString(remaining)} more entries`)
      | false => ()
      }
    }
  }

  lines->Array.push(".")
  walk(root, ~prefix="", ~currentDepth=1, ~parentPath=None)

  lines->Array.join("\n")
}

// Build a mapping from full relative workspace path => workspace name for annotation.
let buildWorkspacePathLookup = (workspaces: array<workspace>): Dict.t<string> => {
  let lookup = Dict.make()
  workspaces->Array.forEach(ws => {
    lookup->Dict.set(ws.path, ws.name)
  })
  lookup
}

let readJsonFile = async (path: string): result<JSON.t, string> => {
  try {
    let content = await Fs.Promises.readFile(path)
    Ok(JSON.parseOrThrow(content))
  } catch {
  | exn =>
    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to read/parse ${path}: ${msg}`)
  }
}

// Read the "name" field from a package.json using Sury schema
let readPackageName = async (dirPath: string): option<string> => {
  let pkgPath = Path.join([dirPath, "package.json"])
  switch await readJsonFile(pkgPath) {
  | Ok(json) =>
    try {
      let pkg = S.parseOrThrow(json, packageJsonNameSchema)
      pkg.name
    } catch {
    | _ => None
    }
  | Error(_) => None
  }
}

// Extract workspace globs from a parsed package.json JSON value.
// workspaces can be either an array of strings or an object with a "packages" key.
let extractWorkspaceGlobs = (json: JSON.t): option<array<string>> => {
  switch json->JSON.Decode.object {
  | Some(obj) =>
    switch obj->Dict.get("workspaces") {
    | Some(wsJson) =>
      // Try as array<string> first
      try {
        let globs = S.parseOrThrow(wsJson, S.array(S.string))
        Some(globs)
      } catch {
      | _ =>
        // Try as {packages: array<string>}
        try {
          let wsObj = S.parseOrThrow(wsJson, packageJsonWorkspacesObjSchema)
          wsObj.packages
        } catch {
        | _ => None
        }
      }
    | None => None
    }
  | None => None
  }
}

// Resolve workspace glob patterns (e.g. "apps/*") against actual directories
let resolveWorkspaceGlobs = async (rootPath: string, globs: array<string>): array<string> => {
  let results: array<string> = []

  let _ = await globs
  ->Array.map(async glob => {
    switch glob->String.endsWith("/*") {
    | true =>
      // Directory glob: "apps/*" -> list entries in "apps/"
      let parentDir = glob->String.slice(~start=0, ~end=String.length(glob) - 2)
      let fullParent = Path.join([rootPath, parentDir])
      try {
        let entries = await Fs.Promises.readdir(fullParent)
        let _ =
          await entries
          ->Array.map(async entry => {
            let entryPath = Path.join([fullParent, entry])
            let stats = await Fs.Promises.stat(entryPath)
            switch Fs.isDirectory(stats) {
            | true => results->Array.push(parentDir ++ "/" ++ entry)
            | false => ()
            }
          })
          ->Promise.all
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Console.warn(`ListTree: failed to resolve workspace glob "${glob}": ${msg}`)
      }
    | false =>
      // Exact path
      let fullPath = Path.join([rootPath, glob])
      switch await FsUtils.pathExists(fullPath) {
      | true => results->Array.push(glob)
      | false => ()
      }
    }
  })
  ->Promise.all

  results
}

type monorepoInfo = {
  monorepoType: option<string>,
  workspaces: array<workspace>,
}

let detectMonorepo = async (rootPath: string): monorepoInfo => {
  // Check for package.json workspaces
  let pkgJsonResult = await readJsonFile(Path.join([rootPath, "package.json"]))

  let workspaceGlobs = switch pkgJsonResult {
  | Ok(json) => extractWorkspaceGlobs(json)
  | Error(_) => None
  }

  // Detect monorepo type indicators
    let hasTurbo = await FsUtils.pathExists(Path.join([rootPath, "turbo.json"]))
    let hasNx = await FsUtils.pathExists(Path.join([rootPath, "nx.json"]))
    let hasPnpmWorkspace = await FsUtils.pathExists(Path.join([rootPath, "pnpm-workspace.yaml"]))

  // Determine monorepo type
  let monorepoType = switch (workspaceGlobs, hasTurbo, hasNx, hasPnpmWorkspace) {
  | (_, true, _, _) => Some("turborepo")
  | (_, _, true, _) => Some("nx")
  | (_, _, _, true) => Some("pnpm-workspaces")
  | (Some(_), _, _, _) => Some("npm-workspaces")
  | _ => None
  }

  // Resolve workspaces
  let workspaces = switch workspaceGlobs {
  | Some(globs) =>
    let resolvedPaths = await resolveWorkspaceGlobs(rootPath, globs)

    await resolvedPaths
    ->Array.map(async wsPath => {
      let fullPath = Path.join([rootPath, wsPath])
      let name = switch await readPackageName(fullPath) {
      | Some(n) => n
      | None => wsPath
      }
      {name, path: wsPath}
    })
    ->Promise.all

  | None => []
  }

  // If no npm/yarn workspaces but pnpm-workspace.yaml exists, try to read it
  // For now we don't parse YAML -- just mark as pnpm-workspaces. The workspace
  // globs from package.json are typically authoritative when they exist.
  {monorepoType, workspaces}
}

let getTrackedFiles = async (~cwd: string): result<array<string>, string> => {
  let result = await ChildProcess.spawnResult("git", ["ls-files"], ~cwd)

  switch result {
  | Ok({stdout}) =>
    let lines = stdout->String.trim->String.split("\n")->Array.filter(line => line !== "")
    Ok(lines)
  | Error({code: Some(128), stderr}) => Error(`Not a git repository: ${stderr}`)
  | Error({stderr}) => Error(`git ls-files failed: ${stderr}`)
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let path = input.path->Option.getOr(".")
  let maxDepth = input.depth->Option.getOr(3)

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    try {
      // If the agent passed a file path, use its parent directory instead.
      // ListTree is directory-centric — a file path means "show the tree near this file".
      let fullPath = try {
        let stats = await Fs.Promises.stat(result.resolvedPath)
        switch Fs.isFile(stats) {
        | true => Path.dirname(result.resolvedPath)
        | false => result.resolvedPath
        }
      } catch {
      | _ => result.resolvedPath
      }

      // Get tracked files
      let filesResult = await getTrackedFiles(~cwd=fullPath)

      let files = switch filesResult {
      | Ok(f) => f
      | Error(errMsg) =>
        // Fallback: single-level readdir if not a git repo.
        // Known limitation: produces a flat list (depth 1) regardless of the
        // depth parameter because readdir returns filenames, not nested paths.
        Console.warn(`ListTree: ${errMsg}, falling back to readdir`)
        let entries = await Fs.Promises.readdir(fullPath)
        entries
      }

      // Build trie
      let trie = buildTrie(files)

      // Detect monorepo (only at the resolved root)
      let monoInfo = await detectMonorepo(fullPath)

      // Build workspace path lookup for annotations
      let workspacePaths = buildWorkspacePathLookup(monoInfo.workspaces)

      // Render
      let tree = renderTree(trie, ~maxDepth, ~workspacePaths)

      Ok({
        tree,
        workspaces: monoInfo.workspaces,
        monorepoType: monoInfo.monorepoType,
      })
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to list tree for ${path}: ${msg}`)
    }
  }
}
