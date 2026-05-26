/**
 * ToolGroupBlock - Grouped tool calls with "Explored" summary
 * 
 * Displays a collapsible group of tool calls with a summary header.
 * When collapsed, shows "Explored 3 files · 2 searches".
 * When expanded, shows individual tool call blocks.
 * 
 * Subagent groups show with "Processed" prefix and distinct styling.
 * 
 * Auto-expand/collapse behavior:
 * - If isLastToolGroup=true, the group auto-expands
 * - When a group is no longer the last (new group created), it auto-collapses
 * - If user manually toggles, their preference is preserved
 * - Shows "Exploring..." while isLastToolGroup && isAgentRunning
 */
module Icons = Client__ToolIcons
module Types = Client__ToolGroupTypes
module Utils = Client__ToolGroupUtils
module ToolCallBlock = Client__ToolCallBlock

let renderCompactToolCall = (~tc: Client__State__Types.Message.toolCall, ~messageId: string) => {
  <ToolCallBlock
    key={tc.id}
    toolName={tc.toolName}
    state={tc.state}
    input={tc.input}
    inputBuffer={tc.inputBuffer}
    result={tc.result}
    errorText={tc.errorText}
    defaultExpanded=false
    compact=true
    messageId
  />
}

@react.component
let make = (
  ~group: Types.toolGroup,
  ~defaultExpanded: bool=false,
  ~isLastToolGroup: bool=false,
  ~isLastItem: bool=false,
  ~isAgentRunning: bool=false,
  ~messageId: string,
) => {
  // Check if any tool in the group is still loading
  let isLoading = group.toolCalls->Array.some(tc => {
    switch tc.state {
    | Client__State__Types.Message.InputStreaming
    | Client__State__Types.Message.InputAvailable => true
    | _ => false
    }
  })

  // Group is "open" if it's the last tool group, the last item, and agent is still running
  // Must be last item because if there are items after (like assistant messages),
  // no more tools can be added to this group
  let isOpen = isLastToolGroup && isLastItem && isAgentRunning

  // Track if user has manually toggled expansion
  let hasUserToggled = React.useRef(false)

  // Track previous isLastToolGroup state for auto-collapse detection
  let prevIsLastToolGroup = React.useRef(isLastToolGroup)

  // Ref for the scrollable container to auto-scroll
  let scrollContainerRef = React.useRef(Nullable.null)

  // Track tool count for auto-scroll detection
  let prevToolCount = React.useRef(Array.length(group.toolCalls))

  // Auto-expand if this is the last tool group (always expand last group)
  let (isExpanded, setIsExpanded) = React.useState(() => defaultExpanded || isLastToolGroup)

  // Auto-expand when becoming the last tool group
  // Auto-collapse when no longer the last tool group (unless user manually toggled)
  React.useEffect2(() => {
    if isLastToolGroup && !prevIsLastToolGroup.current {
      // Just became the last tool group - auto-expand
      setIsExpanded(_ => true)
    } else if !isLastToolGroup && prevIsLastToolGroup.current && !hasUserToggled.current {
      // No longer the last tool group and user hasn't toggled - auto-collapse
      setIsExpanded(_ => false)
    }
    prevIsLastToolGroup.current = isLastToolGroup
    None
  }, (isLastToolGroup, hasUserToggled.current))

  // Raw JS helper for smooth scrolling to bottom
  let scrollToBottom: Dom.element => unit = %raw(`
    function(element) {
      element.scrollTo({ top: element.scrollHeight, behavior: 'smooth' });
    }
  `)

  // Auto-scroll to bottom when new tools are added to the last group
  React.useEffect2(() => {
    let currentCount = Array.length(group.toolCalls)
    if isLastToolGroup && isExpanded && currentCount > prevToolCount.current {
      // New tool was added - scroll to bottom
      switch scrollContainerRef.current->Nullable.toOption {
      | Some(container) => scrollToBottom(container)
      | None => ()
      }
    }
    prevToolCount.current = currentCount
    None
  }, (Array.length(group.toolCalls), isExpanded))

  // Check if this is a subagent group
  let isSubagent = group.groupType == Types.Subagent

  // Generate appropriate summary labels
  let summaryLabels = if isSubagent {
    [Utils.generateSubagentSummaryLabel(group.summary)]
  } else {
    Utils.generateSummaryLabels(group.summary)
  }
  let toolCount = Array.length(group.toolCalls)

  // Get dynamic prefix (Exploring/Explored based on loading state and open state)
  let displayPrefix = Utils.getGroupPrefix(group, ~isOpen)

  // Toggle expansion - mark as user-toggled to prevent auto-expand interference
  let handleToggle = _ => {
    hasUserToggled.current = true
    setIsExpanded(prev => !prev)
  }

  // Style variants for subagent vs main agent groups - purple themed
  let headerBgClass = if isSubagent {
    "bg-indigo-950/50 hover:bg-indigo-900/50"
  } else {
    "bg-[#8051CD]/10 hover:bg-[#8051CD]/15"
  }

  let borderLineClass = if isSubagent {
    "border-indigo-600/40"
  } else {
    "border-[#8051CD]/30"
  }

  // Show shimmer effect when group is loading OR open (last group with agent running)
  let showShimmer = isLoading || isOpen
  let prefixColorClass = if isSubagent {
    if showShimmer {
      "shimmer-text"
    } else {
      "text-indigo-400"
    }
  } else if showShimmer {
    "shimmer-text"
  } else {
    "text-zinc-400"
  }

  <div className="my-1.5 mx-3 animate-in fade-in duration-100">
    // Collapsed Summary Header - purple themed
    <div
      className={`group flex items-center gap-1.5 px-3 py-2 rounded-lg cursor-pointer 
                  transition-colors duration-150 ${headerBgClass}`}
      onClick={handleToggle}
    >
      // Expand/Collapse Chevron (left side)
      <button
        type_="button"
        className="flex items-center justify-center w-4 h-4 shrink-0
                   text-zinc-400 transition-transform duration-200"
      >
        <Icons.ChevronDownIcon size=10 className={isExpanded ? "rotate-180" : "-rotate-90"} />
      </button>
      // Subagent icon (for subagent groups)
      {isSubagent
        ? <svg
            className="w-3 h-3 text-indigo-400 shrink-0"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
          >
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        : React.null}
      // Prefix Label
      <span className={`text-xs shrink-0 ${prefixColorClass}`}>
        {React.string(displayPrefix)}
      </span>
      // Spawning tool name (for subagent groups)
      {switch group.spawningToolName {
      | Some(toolName) =>
        <span className="text-xs text-indigo-300 font-mono truncate max-w-[180px]">
          {React.string(Client__ToolLabels.toTitleCase(toolName))}
        </span>
      | None => React.null
      }}
      // Summary Items
      <div className="flex items-center gap-1 text-xs min-w-0 overflow-hidden flex-1">
        {summaryLabels
        ->Array.mapWithIndex((label, i) => {
          <React.Fragment key={Int.toString(i)}>
            {i > 0 || Option.isSome(group.spawningToolName)
              ? <span className="text-zinc-600 shrink-0"> {React.string(" · ")} </span>
              : React.null}
            <span className="text-zinc-200 truncate"> {React.string(label)} </span>
          </React.Fragment>
        })
        ->React.array}
      </div>
      // Tool count badge
      <span className="text-[10px] text-zinc-400 bg-[#8051CD]/20 px-1.5 py-0.5 rounded shrink-0">
        {React.string(Int.toString(toolCount))}
      </span>
    </div>
    // Expanded Children - scrollable with max height
    {
      let renderContent =
        group.toolCalls
        ->Array.mapWithIndex((tc, i) => {
          renderCompactToolCall(~tc, ~messageId=`${messageId}-${Int.toString(i)}`)
        })
        ->React.array

      <div
        className={`frontman-collapse-transition
                    ${isExpanded ? "opacity-100 mt-1" : "max-h-0 opacity-0 overflow-hidden"}`}
      >
        <div
          ref={ReactDOM.Ref.domRef(scrollContainerRef)}
          className={`pl-4 border-l-2 space-y-0.5 max-h-[150px] overflow-y-auto scroll-smooth ${borderLineClass}`}
        >
          {renderContent}
        </div>
      </div>
    }
  </div>
}
