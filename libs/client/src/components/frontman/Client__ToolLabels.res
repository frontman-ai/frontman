/**
 * ToolLabels - Progressive label generation for tool operations
 *
 * Generates context-aware labels like "Reading...", "Read", etc.
 * based on tool name and current state.
 */

/**
 * Extract a display-friendly target from tool input
 * Attempts to find common fields like "path", "file", "query", "command"
 */
let extractTargetFromInput = (input: option<JSON.t>): option<string> => {
  switch input {
  | None => None
  | Some(json) =>
    // Try to decode as an object and look for common fields
    switch JSON.Decode.object(json) {
    | None => None
    | Some(dict) =>
      // Check common field names in order of priority
      let fields = ["target_file", "file_path", "path", "target_directory", "file", "query", "command", "pattern", "url", "target"]

      fields->Array.reduce(None, (acc, field) => {
        switch acc {
        | Some(_) => acc // Already found one
        | None =>
          dict->Dict.get(field)->Option.flatMap(value => {
            switch JSON.Decode.string(value) {
            | Some(str) if String.length(str) > 0 =>
              // Truncate long strings
              let truncated = if String.length(str) > 40 {
                String.slice(str, ~start=0, ~end=37) ++ "..."
              } else {
                str
              }
              Some(truncated)
            | _ => None
            }
          })
        }
      })
    }
  }
}
