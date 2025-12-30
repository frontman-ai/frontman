open ContextLoader__Types

module Bindings = FrontmanBindings
module Path = Bindings.Path
module Os = Bindings.Os

let localFileNames = ["AGENTS.md", "CLAUDE.md", "CONTEXT.md"]

let globalFilePaths = (globalConfigDir: option<string>): array<string> => {
  switch globalConfigDir {
  | Some(customDir) => [
      Path.join([customDir, "AGENTS.md"]),
      Path.join([customDir, ".claude", "CLAUDE.md"]),
    ]
  | None => [
      Path.join([Os.homedir(), ".config", "claude", "AGENTS.md"]),
      Path.join([Os.homedir(), ".claude", "CLAUDE.md"]),
    ]
  }
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

let getDirectoriesFromRootToCwd = (~root: string, ~cwd: string): array<string> => {
  // Walk up from cwd to root, collecting directories
  let rec walkUp = (current: string, acc: array<string>): array<string> => {
    if current == root || isRoot(current) {
      Array.concat([current], acc)
    } else {
      let parentDir = parent(current)
      if parentDir == current {
        Array.concat([current], acc)
      } else {
        walkUp(parentDir, Array.concat([current], acc))
      }
    }
  }

  // Walk up and reverse to get root → cwd ordering
  let directories = walkUp(cwd, [])
  directories
}

let generateLocalPaths = (filename: string, ~cwd: string, ~root: string): array<string> => {
  let directories = getDirectoriesFromRootToCwd(~root, ~cwd)
  directories->Array.map(dir => Path.join([dir, filename]))
}

let generateLocalCandidates = (~cwd: string, ~root: string): array<(string, array<string>)> => {
  // Get all directories from root to cwd
  let directories = getDirectoriesFromRootToCwd(~root, ~cwd)

  // For each directory, generate candidate paths for all filenames
  directories->Array.map(dir => {
    let candidatePaths = localFileNames->Array.map(filename => Path.join([dir, filename]))
    (dir, candidatePaths)
  })
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
