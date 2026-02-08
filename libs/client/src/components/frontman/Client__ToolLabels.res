/**
 * ToolLabels - Progressive label generation for tool operations
 *
 * Generates context-aware labels like "Reading...", "Read", etc.
 * based on tool name and current state.
 */

/**
 * Convert snake_case tool name to Title Case for display
 * e.g., "get_routes" -> "Get Routes", "write_file" -> "Write File"
 * Also strips "Calling " prefix if present (legacy server format)
 */
let toTitleCase = (str: string): string => {
  // Strip "Calling " prefix if present (legacy server format)
  let cleanStr = if String.startsWith(str, "Calling ") {
    String.slice(str, ~start=8, ~end=String.length(str))
  } else {
    str
  }
  
  cleanStr
  ->String.split("_")
  ->Array.map(word => {
    if String.length(word) > 0 {
      let first = word->String.charAt(0)->String.toUpperCase
      let rest = word->String.slice(~start=1, ~end=String.length(word))->String.toLowerCase
      first ++ rest
    } else {
      word
    }
  })
  ->Array.join(" ")
}

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
