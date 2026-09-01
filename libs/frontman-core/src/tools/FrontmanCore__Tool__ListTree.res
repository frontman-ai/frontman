module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module ChildProcess = FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext
module FsUtils = FrontmanCore__FsUtils
module PathRecovery = FrontmanCore__PathRecovery
module ToolPathHints = FrontmanCore__ToolPathHints

let name = Tool.ToolNames.listTree
let access = Tool.Read
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

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

@schema
type packageJsonName = {name?: string}

@schema
type packageJsonWorkspacesObj = {packages?: array<string>}

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

let maxEntriesPerLevel = 15
let showEntriesBeforeTruncation = 10

type rec trieNode = {
  @live
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

let renderTree = (root: trieNode, ~maxDepth: int, ~workspacePaths: Dict.t<string>): string => {
  let lines: array<string> = []

  let rec walk = (
    node: trieNode,
    ~prefix: string,
    ~currentDepth: int,
    ~parentPath: option<string>,
  ) => {
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

        let entryRelPath = switch parentPath {
        | None => entry.entryName
        | Some(p) => p ++ "/" ++ entry.entryName
        }

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
          walk(
            entry.node,
            ~prefix=childPrefix,
            ~currentDepth=currentDepth + 1,
            ~parentPath=Some(entryRelPath),
          )
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
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to read/parse ${path}: ${msg}`)
  }
}

let readPackageName = async (dirPath: string): option<string> => {
  let pkgPath = Path.join([dirPath, "package.json"])
  switch await readJsonFile(pkgPath) {
  | Ok(json) =>
    try {
      let pkg = S.parseOrThrow(json, ~to=packageJsonNameSchema)
      pkg.name
    } catch {
    | _ => None
    }
  | Error(_) => None
  }
}

let extractWorkspaceGlobs = (json: JSON.t): option<array<string>> => {
  switch json->JSON.Decode.object {
  | Some(obj) =>
    switch obj->Dict.get("workspaces") {
    | Some(wsJson) =>
      try {
        let globs = S.parseOrThrow(wsJson, ~to=S.array(S.string))
        Some(globs)
      } catch {
      | _ =>
        try {
          let wsObj = S.parseOrThrow(wsJson, ~to=packageJsonWorkspacesObjSchema)
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

let resolveWorkspaceGlobs = async (rootPath: string, globs: array<string>): array<string> => {
  let results: array<string> = []

  let _ = await globs
  ->Array.map(async glob => {
    switch glob->String.endsWith("/*") {
    | true =>
      let parentDir = glob->String.slice(~start=0, ~end=String.length(glob) - 2)
      let fullParent = Path.join([rootPath, parentDir])
      try {
        let entries = await Fs.Promises.readdir(fullParent)
        let _ = await entries
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
  let pkgJsonResult = await readJsonFile(Path.join([rootPath, "package.json"]))

  let workspaceGlobs = switch pkgJsonResult {
  | Ok(json) => extractWorkspaceGlobs(json)
  | Error(_) => None
  }

  let hasTurbo = await FsUtils.pathExists(Path.join([rootPath, "turbo.json"]))
  let hasNx = await FsUtils.pathExists(Path.join([rootPath, "nx.json"]))
  let hasPnpmWorkspace = await FsUtils.pathExists(Path.join([rootPath, "pnpm-workspace.yaml"]))

  let monorepoType = switch (workspaceGlobs, hasTurbo, hasNx, hasPnpmWorkspace) {
  | (_, true, _, _) => Some("turborepo")
  | (_, _, true, _) => Some("nx")
  | (_, _, _, true) => Some("pnpm-workspaces")
  | (Some(_), _, _, _) => Some("npm-workspaces")
  | _ => None
  }

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

  {monorepoType, workspaces}
}

let getTrackedFiles = async (~cwd: string, ~signal: WebAPI.EventTypes.abortSignal): result<
  array<string>,
  string,
> => {
  let result = await ChildProcess.spawnResult("git", ["ls-files"], ~cwd, ~signal)

  switch result {
  | Ok({stdout}) =>
    let lines = stdout->String.trim->String.split("\n")->Array.filter(line => line !== "")
    Ok(lines)
  | Error({code: Some(128), stderr}) => Error(`Not a git repository: ${stderr}`)
  | Error({stderr}) => Error(`git ls-files failed: ${stderr}`)
  }
}

let executeOutput = async (ctx: Tool.serverExecutionContext, input: input): result<
  output,
  string,
> => {
  let path = input.path->Option.getOr(".")
  let maxDepth = input.depth->Option.getOr(3)

  switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=path) {
  | Error(err) => Error(PathContext.formatError(err))
  | Ok(result) =>
    try {
      let initialPath = try {
        let stats = await Fs.Promises.stat(result.resolvedPath)
        switch Fs.isFile(stats) {
        | true => Path.dirname(result.resolvedPath)
        | false => result.resolvedPath
        }
      } catch {
      | _ => result.resolvedPath
      }

      let nearestDir = await PathRecovery.nearestExistingDir(
        ~sourceRoot=ctx.sourceRoot,
        ~startPath=initialPath,
      )

      switch nearestDir {
      | None => Error(`Failed to list tree for ${path}: no existing directory found`)
      | Some(fullPath) =>
        let requestedRecovered = Path.normalize(fullPath) != Path.normalize(initialPath)
        let relativeFullPath = PathContext.toRelativePath(
          ~sourceRoot=ctx.sourceRoot,
          ~absolutePath=fullPath,
        )

        let filesResult = await getTrackedFiles(~cwd=fullPath, ~signal=ctx.signal)

        let files = switch filesResult {
        | Ok(f) => f
        | Error(errMsg) =>
          Console.warn(`ListTree: ${errMsg}, falling back to readdir`)
          let entries = await Fs.Promises.readdir(fullPath)
          entries
        }

        let trie = buildTrie(files)

        let monoInfo = await detectMonorepo(fullPath)

        let workspacePaths = buildWorkspacePathLookup(monoInfo.workspaces)

        let renderedTree = renderTree(trie, ~maxDepth, ~workspacePaths)

        let tree = switch requestedRecovered {
        | true =>
          `[recovered] requested path "${path}" was not found. Showing nearest existing directory "${relativeFullPath}".\n` ++
          renderedTree
        | false => renderedTree
        }

        ToolPathHints.recordListAnchor(~sourceRoot=ctx.sourceRoot, ~path=relativeFullPath)

        Ok({
          tree,
          workspaces: monoInfo.workspaces,
          monorepoType: monoInfo.monorepoType,
        })
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to list tree for ${path}: ${msg}`)
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await executeOutput(ctx, input) {
  | Ok(output) => Tool.structuredResult(output, outputSchema)
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
