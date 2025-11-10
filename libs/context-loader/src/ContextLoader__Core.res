open ContextLoader__Types

module Bindings = AskTheLlmBindings
module Path = Bindings.Path
module Os = Bindings.Os

let localFileNames = ["AGENTS.md", "CLAUDE.md", "CONTEXT.md"]

let globalFilePaths = (globalConfigDir: option<string>): array<string> => {
  let configDir = globalConfigDir->Option.getOr(Path.join([Os.homedir(), ".config", "claude"]))
  let claudeDir = Path.join([Os.homedir(), ".claude"])

  [Path.join([configDir, "AGENTS.md"]), Path.join([claudeDir, "CLAUDE.md"])]
}

let expandTilde = (path: string): string => {
  if String.startsWith(path, "~/") || path == "~" {
    Path.join([Os.homedir(), String.slice(path, ~start=1, ~end=String.length(path))])
  } else {
    path
  }
}

let normalize = (path: string, ~cwd: string): string => {
  let expanded = expandTilde(path)
  if Path.isAbsolute(expanded) {
    Path.resolve(expanded)
  } else {
    Path.resolveMany([cwd, expanded])
  }
}

let parent = (path: string): string => {
  let parentPath = Path.dirname(path)
  if parentPath == path {
    path
  } else {
    parentPath
  }
}

let isRoot = (path: string): bool => {
  path == Path.dirname(path)
}

let generateLocalPaths = (filename: string, ~cwd: string, ~root: string): array<string> => {
  let rec traverse = (current: string, acc: array<string>): array<string> => {
    let candidatePath = Path.join([current, filename])
    let newAcc = Array.concat(acc, [candidatePath])

    if current == root || isRoot(current) {
      newAcc
    } else {
      let parentDir = parent(current)
      if parentDir == current {
        newAcc
      } else {
        traverse(parentDir, newAcc)
      }
    }
  }

  traverse(cwd, [])
}

let generateLocalCandidates = (~cwd: string, ~root: string): array<(string, array<string>)> => {
  localFileNames->Array.map(filename => (filename, generateLocalPaths(filename, ~cwd, ~root)))
}

let makeLoadedFile = (
  path: string,
  content: string,
  source: source,
  ~discovered: bool,
): loadedFile => {
  {
    path,
    content,
    source,
    discovered,
  }
}

let filterEmpty = (files: array<loadedFile>): array<loadedFile> => {
  files->Array.filter(file => String.length(file.content) > 0)
}

let calculateTotalSize = (files: array<loadedFile>): int => {
  files->Array.reduce(0, (acc, file) => acc + String.length(file.content))
}

let buildLoadedContext = (files: array<loadedFile>): loadedContext => {
  let content = files->Array.map(file => file.content)
  let totalSize = calculateTotalSize(files)

  {
    files,
    content,
    totalSize,
  }
}
