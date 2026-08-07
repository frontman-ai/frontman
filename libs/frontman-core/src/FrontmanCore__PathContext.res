module SafePath = FrontmanCore__SafePath
module Path = FrontmanBindings.Path
module PathStringUtils = FrontmanCore__PathStringUtils

type resolveResult = {
  safePath: SafePath.t,
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

type resolveError = {
  message: string,
  hint: option<string>,
  sourceRoot: string,
  @live
  requestedPath: string,
}

type responseContext = {
  @live
  sourceRoot: string,
  @live
  resolvedPath: string,
  @live
  relativePath: string,
}

let endsWithSep = (path: string): bool => {
  path->String.endsWith("/") || path->String.endsWith("\\")
}

let toRelativePath = (~sourceRoot: string, ~absolutePath: string): string => {
  let sourceRoot = Path.resolve(sourceRoot)
  let normalizedRoot = if endsWithSep(sourceRoot) {
    sourceRoot
  } else {
    sourceRoot ++ Path.sep
  }

  if absolutePath->String.startsWith(normalizedRoot) {
    absolutePath->String.slice(
      ~start=normalizedRoot->String.length,
      ~end=absolutePath->String.length,
    )
  } else if absolutePath->String.startsWith(sourceRoot) {
    absolutePath->String.slice(~start=sourceRoot->String.length, ~end=absolutePath->String.length)
  } else {
    absolutePath
  }
}

let resolveSearchPath = (~sourceRoot: string, ~inputPath: option<string>): string => {
  switch inputPath {
  | None => sourceRoot
  | Some(path) =>
    if Path.isAbsolute(path) {
      let normalizedPath = Path.normalize(path)
      let normalizedRoot = Path.normalize(sourceRoot)
      if normalizedPath->String.startsWith(normalizedRoot) {
        normalizedPath
      } else {
        sourceRoot
      }
    } else {
      Path.join([sourceRoot, path])
    }
  }
}

module Fs = FrontmanBindings.Fs

let resolveSearchDir = async (~sourceRoot: string, ~inputPath: option<string>): string => {
  let resolved = resolveSearchPath(~sourceRoot, ~inputPath)
  try {
    let stats = await Fs.Promises.stat(resolved)
    switch Fs.isFile(stats) {
    | true => Path.dirname(resolved)
    | false => resolved
    }
  } catch {
  | _ => resolved
  }
}

let detectPathConfusion = (~sourceRoot: string, ~requestedPath: string): option<string> => {
  let normalizedPath =
    requestedPath
    ->PathStringUtils.toForwardSlashes
    ->String.replaceRegExp(/^\.\//, "")
    ->String.replaceRegExp(/^\//, "")

  let firstSegment = normalizedPath->String.split("/")->Array.get(0)->Option.getOr("")

  let sourceSegments = sourceRoot->PathStringUtils.toForwardSlashes->String.split("/")

  if firstSegment != "" && sourceSegments->Array.includes(firstSegment) {
    Some(
      `Path '${requestedPath}' not found. The sourceRoot is '${sourceRoot}' which already includes '${firstSegment}/'. Try using '.' or a path relative to sourceRoot instead.`,
    )
  } else {
    None
  }
}

let dirname = (result: resolveResult): string => {
  SafePath.dirname(result.safePath)
}

let resolve = (~sourceRoot: string, ~inputPath: string): result<resolveResult, resolveError> => {
  switch SafePath.resolve(~sourceRoot, ~inputPath) {
  | Ok(safePath) =>
    let resolvedPath = SafePath.toString(safePath)
    Ok({
      safePath,
      sourceRoot,
      resolvedPath,
      relativePath: toRelativePath(~sourceRoot, ~absolutePath=resolvedPath),
    })
  | Error(msg) =>
    Error({
      message: msg,
      hint: detectPathConfusion(~sourceRoot, ~requestedPath=inputPath),
      sourceRoot,
      requestedPath: inputPath,
    })
  }
}

let formatError = (err: resolveError): string => {
  let base = `${err.message} (sourceRoot: ${err.sourceRoot})`
  switch err.hint {
  | Some(hint) => `${base}\n\nHint: ${hint}`
  | None => base
  }
}

@@live
let makeResponseContext = (~sourceRoot: string, ~resolvedPath: string): responseContext => {
  {
    sourceRoot,
    resolvedPath,
    relativePath: toRelativePath(~sourceRoot, ~absolutePath=resolvedPath),
  }
}

@@live
let contextFromResult = (result: resolveResult): responseContext => {
  {
    sourceRoot: result.sourceRoot,
    resolvedPath: result.resolvedPath,
    relativePath: result.relativePath,
  }
}
