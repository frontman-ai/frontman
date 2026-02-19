// FileTracker - Ensures files are read before being edited
//
// Records which files have been read (by resolved absolute path) and
// provides an assertion that a file was read before allowing edits.
// This prevents blind edits from agents that haven't seen the current content.

// Global mutable set of read file paths
let readFiles: ref<Set.t<string>> = ref(Set.make())

// Record that a file was read (called by ReadFile after successful read)
let recordRead = (resolvedPath: string): unit => {
  readFiles.contents->Set.add(resolvedPath)
}

// Assert a file was read before editing. Returns Error if not.
let assertReadBefore = (resolvedPath: string): result<unit, string> => {
  switch readFiles.contents->Set.has(resolvedPath) {
  | true => Ok()
  | false =>
    Error(
      `File must be read before editing. Use read_file on "${resolvedPath}" first to see its current content.`,
    )
  }
}

// Clear all tracked reads (useful for testing)
let clear = (): unit => {
  readFiles := Set.make()
}
