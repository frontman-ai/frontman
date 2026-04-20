// PathContext - Agent-facing path utilities with helpful errors and context
//
// This module wraps SafePath and provides:
// - Rich error messages with path confusion detection
// - Path conversion utilities (relative/absolute)
// - Response context generation for tool outputs
//
// Architecture:
// - SafePath: Low-level security (traversal prevention)
// - PathContext: Developer experience (helpful errors, context)

module SafePath = FrontmanCore__SafePath
module Path = FrontmanBindings.Path
module PathStringUtils = FrontmanCore__PathStringUtils

// ============================================
// Types
// ============================================

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
  requestedPath: string,
}

type responseContext = {
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

// ============================================
// Path Conversion Utilities
// ============================================

// Check if a string ends with a path separator (handles both / and \)
let endsWithSep = (path: string): bool => {
  path->String.endsWith("/") || path->String.endsWith("\\")
}

// Convert absolute path to relative (relative to sourceRoot)
let toRelativePath = (~sourceRoot: string, ~absolutePath: string): string => {
  // Use Path.sep for cross-platform compatibility (/ on Unix, \ on Windows)
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
    // Handle case where path matches exactly without trailing separator
    absolutePath->String.slice(~start=sourceRoot->String.length, ~end=absolutePath->String.length)
  } else {
    absolutePath
  }
}

// ============================================
// Search Path Resolution
// ============================================

// Resolve search path for commands that accept optional path parameter
// Returns sourceRoot if no path provided, otherwise validates path is under sourceRoot
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
        sourceRoot // Fallback to sourceRoot if outside
      }
    } else {
      Path.join([sourceRoot, path])
    }
  }
}

module Fs = FrontmanBindings.Fs

// Like resolveSearchPath, but guarantees the result is a directory.
// If the resolved path points to a file, returns its parent directory instead.
// Useful for tools that require a directory (e.g. search_files, list_tree)
// where the agent may pass a file path meaning "search near this file".
let resolveSearchDir = async (~sourceRoot: string, ~inputPath: option<string>): string => {
  let resolved = resolveSearchPath(~sourceRoot, ~inputPath)
  try {
    let stats = await Fs.Promises.stat(resolved)
    switch Fs.isFile(stats) {
    | true => Path.dirname(resolved)
    | false => resolved
    }
  } catch {
  // stat failure (path doesn't exist, etc.) — return as-is and let the
  // caller report the actual error.
  | _ => resolved
  }
}

// ============================================
// Path Confusion Detection
// ============================================

// Detect if agent might be confused about paths
// e.g., asking for "web" when sourceRoot=/repo/web
let detectPathConfusion = (~sourceRoot: string, ~requestedPath: string): option<string> => {
  // Normalize separators for consistent splitting on both Unix and Windows
  // Strip leading ./ or /
  let normalizedPath =
    requestedPath
    ->PathStringUtils.toForwardSlashes
    ->String.replaceRegExp(/^\.\//, "")
    ->String.replaceRegExp(/^\//, "")

  // Get first segment of requested path
  let firstSegment = normalizedPath->String.split("/")->Array.get(0)->Option.getOr("")

  // Check if first segment appears in sourceRoot path segments
  let sourceSegments = sourceRoot->PathStringUtils.toForwardSlashes->String.split("/")

  if firstSegment != "" && sourceSegments->Array.includes(firstSegment) {
    Some(
      `Path '${requestedPath}' not found. The sourceRoot is '${sourceRoot}' which already includes '${firstSegment}/'. Try using '.' or a path relative to sourceRoot instead.`,
    )
  } else {
    None
  }
}

// ============================================
// Path Operations
// ============================================

// Get the parent directory of a resolved path
// Safe because the parent of a validated path is always under sourceRoot (or equal to it)
let dirname = (result: resolveResult): string => {
  SafePath.dirname(result.safePath)
}

// ============================================
// Core Resolution
// ============================================

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

// ============================================
// Error Formatting
// ============================================

let formatError = (err: resolveError): string => {
  let base = `${err.message} (sourceRoot: ${err.sourceRoot})`
  switch err.hint {
  | Some(hint) => `${base}\n\nHint: ${hint}`
  | None => base
  }
}

// ============================================
// Response Context Generation
// ============================================

let makeResponseContext = (~sourceRoot: string, ~resolvedPath: string): responseContext => {
  {
    sourceRoot,
    resolvedPath,
    relativePath: toRelativePath(~sourceRoot, ~absolutePath=resolvedPath),
  }
}

// Convenience: create context from resolveResult
let contextFromResult = (result: resolveResult): responseContext => {
  {
    sourceRoot: result.sourceRoot,
    resolvedPath: result.resolvedPath,
    relativePath: result.relativePath,
  }
}
