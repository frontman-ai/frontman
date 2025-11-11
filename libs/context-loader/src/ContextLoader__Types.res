// Context file source types
type source =
  | Local // Found in project directory tree
  | Global // Found in global config directory
  | Custom // Explicitly specified path

let sourceToString = (source: source): string => {
  switch source {
  | Local => "local"
  | Global => "global"
  | Custom => "custom"
  }
}

// Loaded file metadata
type loadedFile = {
  path: string, // Absolute path to the file
  content: string, // File contents
  source: source, // Where it was found
  discovered: bool, // true if found by discovery, false if explicitly specified
}

// Complete loaded context result
@schema
type loadedContext = {
  files: array<loadedFile>, // All loaded files with metadata
  content: array<string>, // Just the content strings (for backward compatibility)
  totalSize: int, // Total character count across all files
}

// Configuration options for loading
type options = {
  cwd: string, // Working directory (required)
  root?: string, // Stop searching here (default: cwd)
  globalConfigDir?: string, // Override default global config directory
  customPaths?: array<string>, // Explicit file paths to include
}

// Result type for operations that can fail
type loadResult<'a> = result<'a, string>
