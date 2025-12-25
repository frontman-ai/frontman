/**
 * ToolLabels - Progressive label generation for tool operations
 * 
 * Generates context-aware labels like "Reading...", "Read", etc.
 * based on tool name and current state.
 */

module Message = Client__State__Types.Message

type labels = {
  progressive: string, // "Reading..."
  completed: string,   // "Read"
  imperative: string,  // "Read"
}

/**
 * Get labels based on tool name category
 */
let getToolLabels = (toolName: string): labels => {
  let lowerName = String.toLowerCase(toolName)
  
  if String.includes(lowerName, "read") || String.includes(lowerName, "get") || String.includes(lowerName, "fetch") {
    { progressive: "Reading", completed: "Read", imperative: "Read" }
  } else if lowerName == "write_file" {
    // Specific handling for write_file tool
    { progressive: "Writing", completed: "Wrote", imperative: "Write" }
  } else if String.includes(lowerName, "edit") || String.includes(lowerName, "write") || String.includes(lowerName, "update") {
    { progressive: "Editing", completed: "Edited", imperative: "Edit" }
  } else if String.includes(lowerName, "create") || String.includes(lowerName, "make") {
    { progressive: "Creating", completed: "Created", imperative: "Create" }
  } else if String.includes(lowerName, "search") || String.includes(lowerName, "find") || String.includes(lowerName, "query") {
    { progressive: "Searching", completed: "Searched", imperative: "Search" }
  } else if String.includes(lowerName, "grep") {
    { progressive: "Grepping", completed: "Grepped", imperative: "Grep" }
  } else if String.includes(lowerName, "terminal") || String.includes(lowerName, "run") || String.includes(lowerName, "exec") || String.includes(lowerName, "command") {
    { progressive: "Running", completed: "Ran", imperative: "Run" }
  } else if String.includes(lowerName, "list") || String.includes(lowerName, "dir") {
    { progressive: "Listing", completed: "Listed", imperative: "List" }
  } else if String.includes(lowerName, "delete") || String.includes(lowerName, "remove") {
    { progressive: "Deleting", completed: "Deleted", imperative: "Delete" }
  } else if String.includes(lowerName, "todo") {
    { progressive: "Updating todos", completed: "Updated todos", imperative: "Update todos" }
  } else if String.includes(lowerName, "lint") || String.includes(lowerName, "fix") {
    { progressive: "Fixing", completed: "Fixed", imperative: "Fix" }
  } else if String.includes(lowerName, "navigate") || String.includes(lowerName, "browser") {
    { progressive: "Navigating", completed: "Navigated", imperative: "Navigate" }
  } else if String.includes(lowerName, "snapshot") || String.includes(lowerName, "screenshot") {
    { progressive: "Capturing", completed: "Captured", imperative: "Capture" }
  } else if String.includes(lowerName, "click") {
    { progressive: "Clicking", completed: "Clicked", imperative: "Click" }
  } else if String.includes(lowerName, "type") || String.includes(lowerName, "input") {
    { progressive: "Typing", completed: "Typed", imperative: "Type" }
  } else if String.includes(lowerName, "wait") {
    { progressive: "Waiting", completed: "Waited", imperative: "Wait" }
  } else if String.includes(lowerName, "mcp") {
    // Try to extract a meaningful action from MCP tool names
    // e.g., "mcp_cursor-ide-browser_browser_snapshot" -> "snapshot"
    let parts = String.split(lowerName, "_")
    let lastPart = parts->Array.get(Array.length(parts) - 1)->Option.getOr("")
    
    // Try to generate labels from the last part
    if String.includes(lastPart, "snapshot") || String.includes(lastPart, "screenshot") {
      { progressive: "Capturing", completed: "Captured", imperative: "Capture" }
    } else if String.includes(lastPart, "click") {
      { progressive: "Clicking", completed: "Clicked", imperative: "Click" }
    } else if String.includes(lastPart, "type") {
      { progressive: "Typing", completed: "Typed", imperative: "Type" }
    } else if String.includes(lastPart, "navigate") {
      { progressive: "Navigating", completed: "Navigated", imperative: "Navigate" }
    } else if String.includes(lastPart, "hover") {
      { progressive: "Hovering", completed: "Hovered", imperative: "Hover" }
    } else if String.includes(lastPart, "select") {
      { progressive: "Selecting", completed: "Selected", imperative: "Select" }
    } else if String.includes(lastPart, "press") {
      { progressive: "Pressing", completed: "Pressed", imperative: "Press" }
    } else if String.includes(lastPart, "wait") {
      { progressive: "Waiting", completed: "Waited", imperative: "Wait" }
    } else if String.includes(lastPart, "resize") {
      { progressive: "Resizing", completed: "Resized", imperative: "Resize" }
    } else {
      // Show the tool action as-is with capitalization
      let action = if String.length(lastPart) > 0 {
        let first = String.charAt(lastPart, 0)->String.toUpperCase
        let rest = String.slice(lastPart, ~start=1, ~end=String.length(lastPart))
        first ++ rest
      } else {
        "Processing"
      }
      { progressive: action ++ "ing", completed: action ++ "ed", imperative: action }
    }
  } else {
    // Extract a meaningful name from the tool for better labels
    // Remove common prefixes and show the action
    let cleaned = lowerName
      ->String.replaceRegExp(Js.Re.fromString("^(mcp_|cursor_)"), "")
    let parts = String.split(cleaned, "_")
    let action = parts->Array.get(Array.length(parts) - 1)->Option.getOr(lowerName)
    
    // Capitalize first letter
    let capitalized = if String.length(action) > 0 {
      let first = String.charAt(action, 0)->String.toUpperCase
      let rest = String.slice(action, ~start=1, ~end=String.length(action))
      first ++ rest
    } else {
      "Processing"
    }
    
    { progressive: capitalized ++ "...", completed: capitalized, imperative: capitalized }
  }
}

/**
 * Get the appropriate label based on current state
 */
let getToolLabel = (toolName: string, state: Message.toolCallState): string => {
  let labels = getToolLabels(toolName)
  
  switch state {
  | InputStreaming | InputAvailable => labels.progressive ++ "..."
  | OutputAvailable => labels.completed
  | OutputError => "Failed"
  }
}

/**
 * Get label with target file/resource
 * e.g., "Reading src/file.ts..."
 */
let getToolLabelWithTarget = (toolName: string, target: string, state: Message.toolCallState): string => {
  let labels = getToolLabels(toolName)
  
  switch state {
  | InputStreaming | InputAvailable => `${labels.progressive} ${target}...`
  | OutputAvailable => `${labels.completed} ${target}`
  | OutputError => `Failed: ${target}`
  }
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

