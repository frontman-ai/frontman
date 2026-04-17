// Path-recovery helpers for resilient tool execution on missing paths.

module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module FsUtils = FrontmanCore__FsUtils
module PathContext = FrontmanCore__PathContext

type recovery = {
  nearestDir: string,
  nearestDirRelative: string,
  siblingEntries: array<string>,
}

let normalize = (path: string): string => Path.normalize(path)

let isUnderSourceRoot = (~candidate: string, ~sourceRoot: string): bool => {
  switch sourceRoot {
  | "/" => candidate->String.startsWith("/")
  | root => candidate == root || candidate->String.startsWith(root ++ "/")
  }
}

let rec nearestExistingDir = async (~sourceRoot: string, ~startPath: string): option<string> => {
  let normalizedRoot = sourceRoot->normalize
  let candidate = startPath->normalize

  switch await FsUtils.dirExists(candidate) {
  | true =>
    switch isUnderSourceRoot(~candidate, ~sourceRoot=normalizedRoot) {
    | true => Some(candidate)
    | false =>
      switch await FsUtils.dirExists(normalizedRoot) {
      | true => Some(normalizedRoot)
      | false => None
      }
    }
  | false =>
    switch candidate == normalizedRoot {
    | true =>
      switch await FsUtils.dirExists(normalizedRoot) {
      | true => Some(normalizedRoot)
      | false => None
      }
    | false =>
      let parent = candidate->Path.dirname->normalize

      switch parent == candidate ||
        !isUnderSourceRoot(~candidate=parent, ~sourceRoot=normalizedRoot) {
      | true =>
        switch await FsUtils.dirExists(normalizedRoot) {
        | true => Some(normalizedRoot)
        | false => None
        }
      | false => await nearestExistingDir(~sourceRoot=normalizedRoot, ~startPath=parent)
      }
    }
  }
}

let sortStrings = (items: array<string>): array<string> => {
  items->Array.toSorted((a, b) => {
    switch String.compare(a, b) {
    | n if n < 0.0 => -1.0
    | n if n > 0.0 => 1.0
    | _ => 0.0
    }
  })
}

let readSiblingEntries = async (~dirPath: string, ~limit: int=12): array<string> => {
  try {
    let entries = await Fs.Promises.readdir(dirPath)
    let sorted = entries->sortStrings
    let visible = sorted->Array.slice(~start=0, ~end=limit)

    await visible
    ->Array.map(async entryName => {
      let entryPath = Path.join([dirPath, entryName])

      try {
        let stats = await Fs.Promises.stat(entryPath)
        switch Fs.isDirectory(stats) {
        | true => entryName ++ "/"
        | false => entryName
        }
      } catch {
      | _ => entryName
      }
    })
    ->Promise.all
  } catch {
  | _ => []
  }
}

let recoverMissingPath = async (
  ~sourceRoot: string,
  ~resolvedPath: string,
  ~entryLimit: int=12,
): option<recovery> => {
  let startDir = resolvedPath->Path.dirname

  switch await nearestExistingDir(~sourceRoot, ~startPath=startDir) {
  | None => None
  | Some(nearestDir) =>
    let siblingEntries = await readSiblingEntries(~dirPath=nearestDir, ~limit=entryLimit)

    Some({
      nearestDir,
      nearestDirRelative: PathContext.toRelativePath(~sourceRoot, ~absolutePath=nearestDir),
      siblingEntries,
    })
  }
}
