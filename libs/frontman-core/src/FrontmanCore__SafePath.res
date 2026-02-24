// Type-safe path handling with validation against sourceRoot
//
// This module provides an opaque SafePath type that can only be constructed
// via the resolve() function, which validates that paths are under sourceRoot.
// This prevents directory traversal attacks and ensures consistent path handling.
//
// Usage:
//   switch SafePath.resolve(~sourceRoot, ~inputPath) {
//   | Error(msg) => Error(msg)
//   | Ok(safePath) => Fs.readFile(SafePath.toString(safePath))
//   }

module Path = FrontmanBindings.Path

// Type representing a validated path under sourceRoot
// Should only be constructed via resolve() - not exported for direct construction
type t = {path: string}

// Check if a path string ends with a path separator (handles both / and \)
let endsWithSep = (path: string): bool => {
  path->String.endsWith("/") || path->String.endsWith("\\")
}

// Resolve and validate a path against sourceRoot
// Accepts both absolute paths (must be under sourceRoot) and relative paths
// Prevents directory traversal attacks like "../../etc/passwd"
let resolve = (~sourceRoot: string, ~inputPath: string): result<t, string> => {
  let normalizedRoot = Path.normalize(sourceRoot)
  // Ensure normalizedRoot ends with separator for proper prefix matching
  // Uses Path.sep for cross-platform compatibility (/ on Unix, \ on Windows)
  let rootWithSep = if endsWithSep(normalizedRoot) {
    normalizedRoot
  } else {
    normalizedRoot ++ Path.sep
  }

  if Path.isAbsolute(inputPath) {
    // Absolute paths must be under sourceRoot
    let normalizedPath = Path.normalize(inputPath)
    // Check if path equals root or starts with root/
    if normalizedPath == normalizedRoot || normalizedPath->String.startsWith(rootWithSep) {
      Ok({path: normalizedPath})
    } else {
      Error(`Absolute path must be under source root: ${inputPath}`)
    }
  } else {
    // Relative paths: join with sourceRoot, normalize, then verify still under sourceRoot
    let fullPath = Path.normalize(Path.join([sourceRoot, inputPath]))
    // Check if path equals root or starts with root/
    if fullPath == normalizedRoot || fullPath->String.startsWith(rootWithSep) {
      Ok({path: fullPath})
    } else {
      Error(`Path escapes source root: ${inputPath}`)
    }
  }
}

// Get the underlying validated path string for filesystem operations
let toString = (safePath: t): string => safePath.path

// Get the directory name of a SafePath
let dirname = (safePath: t): string => Path.dirname(safePath.path)

// Join a SafePath with additional path segments
// Re-validates the result to ensure it's still under sourceRoot
let join = (~sourceRoot: string, safePath: t, segments: array<string>): result<t, string> => {
  let newPath = Path.join(Array.concat([safePath.path], segments))
  resolve(~sourceRoot, ~inputPath=newPath)
}
