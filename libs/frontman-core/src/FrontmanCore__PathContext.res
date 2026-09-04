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

let toRelativePath = (~sourceRoot: string, ~absolutePath: string): string =>
  Path.relative(Path.resolve(sourceRoot), absolutePath)

let resolveSearchPath = (~sourceRoot: string, ~inputPath: option<string>): result<
  string,
  resolveError,
> => {
  switch inputPath {
  | None => Ok(Path.resolve(sourceRoot))
  | Some(path) =>
    switch SafePath.resolve(~sourceRoot, ~inputPath=path) {
    | Ok(safePath) => Ok(SafePath.toString(safePath))
    | Error(message) => Error({message, hint: None, sourceRoot, requestedPath: path})
    }
  }
}

module Fs = FrontmanBindings.Fs

let resolveSearchDir = async (~sourceRoot: string, ~inputPath: option<string>): result<
  string,
  resolveError,
> => {
  switch resolveSearchPath(~sourceRoot, ~inputPath) {
  | Error(_) as error => error
  | Ok(resolved) =>
    try {
      let stats = await Fs.Promises.stat(resolved)
      switch Fs.isFile(stats) {
      | true => Ok(Path.dirname(resolved))
      | false => Ok(resolved)
      }
    } catch {
    | _ => Ok(resolved)
    }
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

let makeError = (~sourceRoot: string, ~requestedPath: string, ~message: string): resolveError => {
  message,
  hint: detectPathConfusion(~sourceRoot, ~requestedPath),
  sourceRoot,
  requestedPath,
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
  | Error(message) => Error(makeError(~sourceRoot, ~requestedPath=inputPath, ~message))
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
