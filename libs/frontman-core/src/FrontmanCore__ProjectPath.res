// Type-safe project path handling with validation against sourceRoot
//
// This module provides an opaque ProjectPath type that can only be constructed
// via the resolve() function, which validates that paths are under sourceRoot.
// This prevents directory traversal attacks and ensures consistent path handling.
//
// Usage:
//   switch ProjectPath.resolve(~sourceRoot, ~inputPath) {
//   | Error(msg) => Error(msg)
//   | Ok(projectPath) => Fs.readFile(ProjectPath.toString(projectPath))
//   }

module NodePath = FrontmanBindings.Path
module Path = FrontmanCore__Path

// Type representing a validated path under sourceRoot
// Should only be constructed via resolve() - not exported for direct construction
type t = {path: string}

// Check if a path string ends with a path separator (handles both / and \)
let endsWithSep = (path: string): bool => {
  path->String.endsWith("/") || path->String.endsWith("\\")
}

let normalizeRoot = (sourceRoot: string): string => NodePath.resolve(sourceRoot)->NodePath.normalize

let isUnderRoot = (~candidate: string, ~root: string): bool => {
  let rootWithSep = if endsWithSep(root) {
    root
  } else {
    root ++ NodePath.sep
  }

  candidate == root || candidate->String.startsWith(rootWithSep)
}

// Resolve and validate a path against sourceRoot
// Accepts both absolute paths (must be under sourceRoot) and relative paths
// Prevents directory traversal attacks like "../../etc/passwd"
let resolveParsed = (~sourceRoot: string, ~inputPath: Path.t): result<t, string> => {
  let normalizedRoot = normalizeRoot(sourceRoot)

  inputPath->Path.fold(
    ~absolute=path => {
      // Absolute paths must be under sourceRoot
      let normalizedPath = NodePath.normalize(path)

      // Check if path equals root or starts with root/
      if isUnderRoot(~candidate=normalizedPath, ~root=normalizedRoot) {
        Ok({path: normalizedPath})
      } else {
        Error(`Absolute path must be under source root: ${inputPath->Path.toString}`)
      }
    },
    ~relative=path => {
      // Relative paths: join with sourceRoot, normalize, then verify still under sourceRoot
      let fullPath = NodePath.resolveMany([normalizedRoot, path])->NodePath.normalize

      // Check if path equals root or starts with root/
      if isUnderRoot(~candidate=fullPath, ~root=normalizedRoot) {
        Ok({path: fullPath})
      } else {
        Error(`Path escapes source root: ${inputPath->Path.toString}`)
      }
    },
  )
}

let resolve = (~sourceRoot: string, ~inputPath: string): result<t, string> => {
  resolveParsed(~sourceRoot, ~inputPath=Path.fromString(inputPath))
}

// Get the underlying validated path string for filesystem operations
let toString = (projectPath: t): string => projectPath.path

// Get the directory name of a ProjectPath
let dirname = (projectPath: t): string => NodePath.dirname(projectPath.path)

// Join a ProjectPath with additional path segments
// Re-validates the result to ensure it's still under sourceRoot
let join = (~sourceRoot: string, projectPath: t, segments: array<string>): result<t, string> => {
  let newPath = NodePath.join(Array.concat([projectPath.path], segments))
  resolve(~sourceRoot, ~inputPath=newPath)
}
