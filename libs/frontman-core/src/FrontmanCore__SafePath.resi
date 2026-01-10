// Type-safe path handling with validation against sourceRoot
//
// This module provides an opaque SafePath type that can only be constructed
// via the resolve() function, which validates that paths are under sourceRoot.
// This prevents directory traversal attacks and ensures consistent path handling.

// Opaque type representing a validated path under sourceRoot
// Cannot be constructed directly - must use resolve()
type t

// Resolve and validate a path against sourceRoot
// Accepts both absolute paths (must be under sourceRoot) and relative paths
// Prevents directory traversal attacks like "../../etc/passwd"
let resolve: (~sourceRoot: string, ~inputPath: string) => result<t, string>

// Get the underlying validated path string for filesystem operations
let toString: t => string

// Get the directory name of a SafePath
let dirname: t => string

// Join a SafePath with additional path segments
// Re-validates the result to ensure it's still under sourceRoot
let join: (~sourceRoot: string, t, array<string>) => result<t, string>
