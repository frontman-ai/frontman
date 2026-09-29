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
Text tree with directories (ending in /) and files. Workspace roots are annotated with [workspace: name]. Includes tracked and non-ignored untracked files in Git repositories. Otherwise walks the filesystem with a fallback notice; .gitignore filtering is not applied. Skips node_modules, .git, dist, build, etc.`

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
  children: Dict.t<trieNode>,
  isFile: ref<bool>,
}

let makeTrieNode = (): trieNode => {
  children: Dict.make(),
  isFile: ref(false),
}

let buildTrie = (files: array<string>): trieNode => {
  let root = makeTrieNode()

  files->Array.forEach(filePath => {
    let leaf =
      filePath
      ->String.split("/")
      ->Array.filter(part => part !== "")
      ->Array.reduce(root, (parent, part) => {
        switch parent.children->Dict.get(part) {
        | Some(node) => node
        | None =>
          let node = makeTrieNode()
          parent.children->Dict.set(part, node)
          node
        }
      })
    leaf.isFile := !(filePath->String.endsWith("/"))
  })

  root
}

type sortedEntry = {
  entryName: string,
  node: trieNode,
  isDir: bool,
}

let getSortedChildren = (node: trieNode): array<sortedEntry> => {
  node.children
  ->Dict.toArray
  ->Array.filter(((entryName, _)) => !isNoiseDir(entryName))
  ->Array.map(((entryName, child)) => {
    let hasChildren = child.children->Dict.keysToArray->Array.length > 0
    let isDir = hasChildren || !child.isFile.contents
    {entryName, node: child, isDir}
  })
  ->Array.toSorted((a, b) => {
    switch (a.isDir, b.isDir) {
    | (true, false) => -1.0
    | (false, true) => 1.0
    | _ => String.compare(a.entryName, b.entryName)
    }
  })
}

let renderTree = (root: trieNode, ~maxDepth: int, ~workspacePaths: Dict.t<string>): string => {
  let lines = ["."]

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
        let (connector, childPrefix) = switch isLastVisible {
        | true => ("└── ", prefix ++ "    ")
        | false => ("├── ", prefix ++ "│   ")
        }

        let suffix = switch entry.isDir {
        | true => "/"
        | false => ""
        }

        let entryRelPath = switch parentPath {
        | None => entry.entryName
        | Some(p) => p ++ "/" ++ entry.entryName
        }

        let workspaceAnnotation = switch (entry.isDir, workspacePaths->Dict.get(entryRelPath)) {
        | (true, Some(wsName)) => ` [workspace: ${wsName}]`
        | _ => ""
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

  walk(root, ~prefix="", ~currentDepth=1, ~parentPath=None)

  lines->Array.join("\n")
}

let buildWorkspacePathLookup = (workspaces: array<workspace>): Dict.t<string> => {
  workspaces->Array.map(ws => (ws.path, ws.name))->Dict.fromArray
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

let getTrackedFiles = async (~cwd: string): result<option<array<string>>, string> => {
  let result = await ChildProcess.spawnResult(
    "git",
    ["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
    ~cwd,
  )

  switch result {
  | Ok({stderr}) if stderr->String.includes("warning: could not open directory") =>
    Error(`git ls-files failed: ${stderr}`)
  | Ok({stdout}) => Ok(Some(stdout->String.split("\x00")->Array.filter(line => line !== "")))
  | Error({stderr, message})
    if stderr->String.includes("not a git repository") || message->String.includes("ENOENT") =>
    Ok(None)
  | Error({stderr, message}) => Error(`git ls-files failed: ${stderr} ${message}`)
  }
}

let walkFiles = async (~cwd: string, ~maxDepth: int): array<string> => {
  let rec walk = async (relativePath, depth) => {
    switch depth > maxDepth {
    | true => []
    | false =>
      let paths = await (await Fs.Promises.readdir(Path.join([cwd, relativePath])))
      ->Array.filter(entry => !isNoiseDir(entry))
      ->Array.map(async entry => {
        let path = [relativePath, entry]->Array.filter(part => part !== "")->Array.join("/")
        let stats = await Fs.Promises.lstat(Path.join([cwd, path]))
        switch Fs.isDirectory(stats) {
        | true => [path ++ "/"]->Array.concat(await walk(path, depth + 1))
        | false => [path]
        }
      })
      ->Promise.all
      paths->Array.flat
    }
  }
  await walk("", 1)
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
      | exn =>
        switch exn->JsExn.fromException->Option.flatMap(e => e->Fs.errorCode->Nullable.toOption) {
        | Some("ENOENT") => result.resolvedPath
        | _ => throw(exn)
        }
      }

      let nearestDir = await PathRecovery.nearestExistingDir(
        ~sourceRoot=ctx.sourceRoot,
        ~startPath=initialPath,
      )

      switch nearestDir {
      | None =>
        Error(
          `Failed to list tree for ${path} (sourceRoot: ${ctx.sourceRoot}, resolved: ${result.resolvedPath}): no existing directory found`,
        )
      | Some(fullPath) =>
        let requestedRecovered = Path.normalize(fullPath) != Path.normalize(initialPath)
        let relativeFullPath = PathContext.toRelativePath(
          ~sourceRoot=ctx.sourceRoot,
          ~absolutePath=fullPath,
        )

        let filesResult = await getTrackedFiles(~cwd=fullPath)

        let (files, notice) = switch filesResult {
        | Ok(Some(f)) => (f, "")
        | Ok(None) => (
            await walkFiles(~cwd=fullPath, ~maxDepth),
            "[filesystem fallback] Git is unavailable or this directory is not a repository; .gitignore filtering was not applied.\n",
          )
        | Error(msg) => JsError.throwWithMessage(msg)
        }

        let trie = buildTrie(files)

        let monoInfo = await detectMonorepo(fullPath)

        let workspacePaths = buildWorkspacePathLookup(monoInfo.workspaces)

        let renderedTree = notice ++ renderTree(trie, ~maxDepth, ~workspacePaths)

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
      Error(
        `Failed to list tree for ${path} (sourceRoot: ${ctx.sourceRoot}, resolved: ${result.resolvedPath}): ${msg}`,
      )
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  switch await executeOutput(ctx, input) {
  | Ok(output) => Tool.structuredResult(output, outputSchema)
  | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
  }
}
