// Shared per-sourceRoot path hints for tool-call guardrails.
//
// The cache stores high-confidence anchors discovered during a session
// (list_tree/list_files/search_files/read_file) plus recent zero-result
// search patterns so read_file can block deterministic guess-reads.

module Path = FrontmanBindings.Path
module PathContext = FrontmanCore__PathContext
module FilenamePattern = FrontmanCore__FilenamePattern
module PathStringUtils = FrontmanCore__PathStringUtils

type zeroSearch = {
  pattern: string,
  searchRoot: string,
  timestampMs: float,
}

type state = {
  anchors: array<string>,
  knownFiles: array<string>,
  zeroSearches: array<zeroSearch>,
}

type searchReduce = {
  nextAnchors: array<string>,
  nextKnownFiles: array<string>,
}

let maxAnchors = 32
let maxKnownFiles = 400
let maxZeroSearches = 24
let zeroSearchTtlMs = 5.0 *. 60.0 *. 1000.0

let states: ref<Dict.t<state>> = ref(Dict.make())

let emptyState = (): state => {
  anchors: [],
  knownFiles: [],
  zeroSearches: [],
}

let stripLeadingDotSlash = (path: string): string => {
  path->String.replaceRegExp(/^\.\//, "")
}

let stripLeadingSlash = (path: string): string => {
  path->String.replaceRegExp(/^\//, "")
}

let normalizePath = (path: string): string => {
  let normalized = path->PathStringUtils.toForwardSlashes->stripLeadingDotSlash->stripLeadingSlash

  switch normalized {
  | "" => "."
  | p if p->String.endsWith("/") => p->String.slice(~start=0, ~end=p->String.length - 1)
  | p => p
  }
}

let getState = (sourceRoot: string): state => {
  switch states.contents->Dict.get(sourceRoot) {
  | Some(existing) => existing
  | None => emptyState()
  }
}

let putState = (sourceRoot: string, nextState: state): unit => {
  states.contents->Dict.set(sourceRoot, nextState)
}

let addUniqueBounded = (items: array<string>, value: string, ~maxItems: int): array<string> => {
  let normalized = value->normalizePath

  switch (normalized == "" || normalized == ".", items->Array.includes(normalized)) {
  | (true, _) => items
  | (_, true) => items
  | _ =>
    let withPrepended = Array.concat([normalized], items)

    switch Array.length(withPrepended) > maxItems {
    | true => withPrepended->Array.slice(~start=0, ~end=maxItems)
    | false => withPrepended
    }
  }
}

let normalizeRelativeToRoot = (~sourceRoot: string, ~path: string): string => {
  let relative = switch Path.isAbsolute(path) {
  | true => PathContext.toRelativePath(~sourceRoot, ~absolutePath=path)
  | false => path
  }

  relative->normalizePath
}

let normalizeFileRelativeToSearchRoot = (
  ~sourceRoot: string,
  ~searchPath: string,
  ~filePath: string,
): string => {
  switch Path.isAbsolute(filePath) {
  | true => normalizeRelativeToRoot(~sourceRoot, ~path=filePath)
  | false => {
      let prefixedPath = Path.join([searchPath, filePath])

      normalizeRelativeToRoot(~sourceRoot, ~path=prefixedPath)
    }
  }
}

let pathIsUnderSearchRoot = (~requestedPath: string, ~searchRoot: string): bool => {
  switch searchRoot {
  | "." => true
  | root =>
    let requestedDir = requestedPath->Path.dirname->normalizePath
    requestedDir == root || requestedDir->String.startsWith(root ++ "/")
  }
}

let removeZeroSearch = (
  zeroSearches: array<zeroSearch>,
  ~pattern: string,
  ~searchRoot: string,
): array<zeroSearch> => {
  zeroSearches->Array.filter(z => !(z.pattern == pattern && z.searchRoot == searchRoot))
}

let isFreshZeroSearch = (~nowMs: float, zeroSearch: zeroSearch): bool => {
  nowMs -. zeroSearch.timestampMs <= zeroSearchTtlMs
}

let recordSearch = (
  ~sourceRoot: string,
  ~searchPath: string,
  ~pattern: string,
  ~files: array<string>,
  ~totalResults: int,
): unit => {
  let state = getState(sourceRoot)
  let normalizedSearchRoot = normalizeRelativeToRoot(~sourceRoot, ~path=searchPath)
  let nowMs = Date.now()

  let seededAnchors = state.anchors->addUniqueBounded(normalizedSearchRoot, ~maxItems=maxAnchors)

  let reduced = files->Array.reduce(
    ({nextAnchors: seededAnchors, nextKnownFiles: state.knownFiles}: searchReduce),
    (acc, filePath) => {
      let normalizedFile = normalizeFileRelativeToSearchRoot(~sourceRoot, ~searchPath, ~filePath)
      let nextKnownFiles =
        acc.nextKnownFiles->addUniqueBounded(normalizedFile, ~maxItems=maxKnownFiles)
      let anchors =
        acc.nextAnchors->addUniqueBounded(
          normalizedFile->Path.dirname->normalizePath,
          ~maxItems=maxAnchors,
        )

      {nextAnchors: anchors, nextKnownFiles}
    },
  )

  let cleanedZeroSearches =
    state.zeroSearches
    ->Array.filter(z => isFreshZeroSearch(~nowMs, z))
    ->removeZeroSearch(~pattern, ~searchRoot=normalizedSearchRoot)

  let zeroSearches = switch totalResults == 0 {
  | true => {
      let withPrepended = Array.concat(
        [
          {
            pattern,
            searchRoot: normalizedSearchRoot,
            timestampMs: nowMs,
          },
        ],
        cleanedZeroSearches,
      )

      switch Array.length(withPrepended) > maxZeroSearches {
      | true => withPrepended->Array.slice(~start=0, ~end=maxZeroSearches)
      | false => withPrepended
      }
    }
  | false => cleanedZeroSearches
  }

  putState(
    sourceRoot,
    {
      anchors: reduced.nextAnchors,
      knownFiles: reduced.nextKnownFiles,
      zeroSearches,
    },
  )
}

let recordReadSuccess = (~sourceRoot: string, ~relativePath: string): unit => {
  let state = getState(sourceRoot)
  let normalizedFile = normalizeRelativeToRoot(~sourceRoot, ~path=relativePath)
  let knownFiles = state.knownFiles->addUniqueBounded(normalizedFile, ~maxItems=maxKnownFiles)
  let anchors =
    state.anchors->addUniqueBounded(
      normalizedFile->Path.dirname->normalizePath,
      ~maxItems=maxAnchors,
    )

  putState(sourceRoot, {...state, knownFiles, anchors})
}

let recordListAnchor = (~sourceRoot: string, ~path: string): unit => {
  let state = getState(sourceRoot)
  let normalizedPath = normalizeRelativeToRoot(~sourceRoot, ~path)
  let anchors = state.anchors->addUniqueBounded(normalizedPath, ~maxItems=maxAnchors)

  putState(sourceRoot, {...state, anchors})
}

let findBlockingZeroSearch = (~sourceRoot: string, ~requestedRelativePath: string): option<
  zeroSearch,
> => {
  let state = getState(sourceRoot)
  let requestedPath = requestedRelativePath->normalizePath
  let nowMs = Date.now()

  switch state.knownFiles->Array.includes(requestedPath) {
  | true => None
  | false =>
    let fileName = requestedPath->Path.basename

    state.zeroSearches->Array.find(z => {
      isFreshZeroSearch(~nowMs, z) &&
      FilenamePattern.matchesPattern(~pattern=z.pattern, ~text=fileName) &&
      pathIsUnderSearchRoot(~requestedPath, ~searchRoot=z.searchRoot)
    })
  }
}

let getAnchors = (~sourceRoot: string): array<string> => {
  getState(sourceRoot).anchors
}

let clear = (): unit => {
  states := Dict.make()
}
