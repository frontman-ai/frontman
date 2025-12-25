/**
 * ToolCallBlock - Main tool call display component
 * 
 * File tools (read_file, write_file, list_files) render as non-expandable links.
 * Other tools render with expand/collapse functionality.
 * 
 * Supports compact mode for grouped display and active state animations.
 */

module Message = Client__State__Types.Message
module Icons = Client__ToolIcons
module ToolStatus = Client__ToolStatus
module ToolLabels = Client__ToolLabels

// File tools show as links, others are expandable
let isFileTool = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)
  name == "read_file" || name == "write_file" || name == "list_files" || name == "list_dir"
}

// Extract target path, defaulting to "./" for list operations
let getTarget = (toolName: string, input: option<JSON.t>): option<string> => {
  switch ToolLabels.extractTargetFromInput(input) {
  | Some(".") => Some("./")
  | Some(t) => Some(t)
  | None if isFileTool(toolName) => Some("./")
  | None => None
  }
}

@react.component
let make = (
  ~toolName: string,
  ~state: Message.toolCallState,
  ~input: option<JSON.t>,
  ~inputBuffer: string,
  ~result: option<JSON.t>,
  ~errorText: option<string>,
  ~defaultExpanded: bool=false,
  ~compact: bool=false,
  ~isSpawner: bool=false, // True for subagent spawner tools - shows indigo styling
  ~messageId as _: string,
) => {
  let isLink = isFileTool(toolName)
  let (isExpanded, setIsExpanded) = React.useState(() => defaultExpanded)
  let (wasManuallyToggled, setWasManuallyToggled) = React.useState(() => false)

  // Sync with defaultExpanded prop unless manually toggled
  React.useEffect(() => {
    if !wasManuallyToggled {
      setIsExpanded(_ => defaultExpanded)
    }
    None
  }, [defaultExpanded])

  let target = getTarget(toolName, input)
  // Show actual tool name instead of processed labels
  let displayName = toolName
  let isInProgress = state == InputStreaming || state == InputAvailable
  let isActive = state == InputAvailable

  // Expandable tools show body when there's content
  let hasBody =
    !isLink &&
    (state == InputStreaming && inputBuffer != "" ||
    Option.isSome(input) ||
    Option.isSome(result) ||
    Option.isSome(errorText))

  // Toggle expansion handler
  let handleToggle = _ => {
    if hasBody {
      setIsExpanded(prev => !prev)
      setWasManuallyToggled(_ => true)
    }
  }

  // Container classes with active state glow - borderless design
  // Spawner tools (subagent spawners) use indigo styling
  let containerClasses = [
    "group rounded-md overflow-hidden",
    "animate-in fade-in duration-100",
    "transition-all duration-150",
    // Background - spawners get indigo, others get zinc
    if isSpawner {
      compact ? "bg-indigo-950/50" : "bg-indigo-950/70"
    } else {
      compact ? "bg-zinc-800/50" : "bg-zinc-800/70"
    },
    // Spacing
    compact ? "my-0.5" : "my-1.5",
    // Active state glow (no border, just shadow)
    isActive ? "shadow-[0_0_8px_rgba(59,130,246,0.2)] ring-1 ring-blue-500/30 frontman-tool-active" : "",
    // Hover state - subtle bg change instead of border
    isSpawner ? "hover:bg-indigo-900/50" : "hover:bg-zinc-700/50",
  ]->Array.filter(s => s != "")->Array.join(" ")

  // Header classes - borderless
  let headerClasses = [
    "flex items-center justify-between gap-2 px-2",
    compact ? "h-6" : "h-7",
    isLink ? "cursor-pointer hover:underline hover:underline-offset-2 hover:decoration-zinc-500" : "",
    hasBody ? "cursor-pointer" : "",
    // No border, just subtle separator via bg
    hasBody && isExpanded ? "bg-zinc-800/30" : "",
  ]->Array.filter(s => s != "")->Array.join(" ")

  // Body transition classes
  let bodyClasses = [
    "overflow-hidden frontman-collapse-transition",
    isExpanded ? "max-h-[300px] opacity-100" : "max-h-0 opacity-0",
  ]->Array.join(" ")

  <div className={containerClasses}>
    <div className={headerClasses} onClick={handleToggle}>
      <div
        className={`flex items-center gap-1.5 flex-1 min-w-0 ${compact ? "text-[11px]" : "text-xs"} text-zinc-400`}>
        <span
          className={`flex items-center justify-center shrink-0 ${compact ? "w-3.5 h-3.5" : "w-4 h-4"}`}>
          {Icons.getToolIcon(toolName, ~size=compact ? 12 : 14)}
        </span>
        <span className="truncate">
          <span className={`font-mono ${isInProgress ? "shimmer-text" : "text-zinc-200"}`}>
            {React.string(displayName)}
          </span>
          {target->Option.mapOr(React.null, t =>
            <span className="text-zinc-500 font-sans"> {React.string(" " ++ t)} </span>
          )}
        </span>
      </div>
      <div className="flex items-center gap-0.5 shrink-0">
        <ToolStatus state compact=true />
        {hasBody
          ? <button
              type_="button"
              className="flex items-center justify-center w-5 h-5 border-none bg-transparent rounded cursor-pointer 
                         opacity-0 group-hover:opacity-50 hover:!opacity-80 transition-opacity text-zinc-200"
              onClick={e => {
                ReactEvent.Mouse.stopPropagation(e)
                handleToggle(e)
              }}>
              <Icons.ChevronDownIcon
                size=12 className={`transition-transform duration-200 ${isExpanded ? "rotate-180" : ""}`}
              />
            </button>
          : React.null}
      </div>
    </div>
    {hasBody
      ? <div className={bodyClasses}>
          <div
            className={`p-2 bg-zinc-900 overflow-auto ${compact ? "max-h-[120px] text-[10px]" : "max-h-[150px] text-xs"}`}>
            {switch (state, input, inputBuffer) {
            | (InputStreaming, None, buf) if buf != "" =>
              <div className="mb-2">
                <div className="text-[11px] text-zinc-500 mb-1">
                  {React.string("Input (streaming):")}
                </div>
                <pre className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                  {React.string(buf)}
                </pre>
              </div>
            | (_, Some(json), _) =>
              <div className="mb-2">
                <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Input:")} </div>
                <pre className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                  {React.string(JSON.stringify(json, ~space=2))}
                </pre>
              </div>
            | _ => React.null
            }}
            {switch (result, errorText) {
            | (Some(json), _) =>
              <div>
                <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Output:")} </div>
                <pre className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                  {React.string(JSON.stringify(json, ~space=2))}
                </pre>
              </div>
            | (None, Some(err)) =>
              <div>
                <div className="text-[11px] text-red-400 mb-1"> {React.string("Error:")} </div>
                <pre className="font-mono text-[11px] whitespace-pre-wrap break-words text-red-400">
                  {React.string(err)}
                </pre>
              </div>
            | _ if state == InputAvailable =>
              <div className="text-sm text-zinc-400 italic py-1">
                {React.string("Executing...")}
              </div>
            | _ => React.null
            }}
          </div>
        </div>
      : React.null}
  </div>
}
