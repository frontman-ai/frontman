/**
 * ToolGroupBlock - Grouped tool calls with "Explored" summary
 * 
 * Displays a collapsible group of tool calls with a summary header.
 * When collapsed, shows "Explored 3 files · 2 searches".
 * When expanded, shows individual tool call blocks.
 * 
 * Subagent groups show with "Processed" prefix and distinct styling.
 * 
 * If isLastGroup=true and the group is still loading, it auto-expands.
 */

module Icons = Client__ToolIcons
module Types = Client__ToolGroupTypes
module Utils = Client__ToolGroupUtils
module ToolCallBlock = Client__ToolCallBlock

// Nested tool group for displaying "Explored" groups within subagent groups
module NestedToolGroup = {
  @react.component
  let make = (~group: Types.toolGroup, ~messageId: string) => {
    let (isExpanded, setIsExpanded) = React.useState(() => false)
    
    let isLoading = group.toolCalls->Array.some(tc => {
      switch tc.state {
      | Client__State__Types.Message.InputStreaming
      | Client__State__Types.Message.InputAvailable => true
      | _ => false
      }
    })
    
    let summaryLabels = Utils.generateSummaryLabels(group.summary)
    let toolCount = Array.length(group.toolCalls)
    let displayPrefix = Utils.getGroupPrefix(group)
    
    let handleToggle = _ => setIsExpanded(prev => !prev)
    
    let prefixColorClass = if isLoading { "shimmer-text" } else { "text-zinc-400" }
    
    <div className="my-0.5">
      <div
        className="group flex items-center gap-1 px-1.5 py-1 rounded cursor-pointer 
                   bg-zinc-800/50 hover:bg-zinc-700/40 transition-colors duration-150"
        onClick={handleToggle}>
        <button
          type_="button"
          className="flex items-center justify-center w-3 h-3 shrink-0 text-zinc-500">
          <Icons.ChevronDownIcon size=8 className={isExpanded ? "rotate-180" : "-rotate-90"} />
        </button>
        <span className={`text-[10px] shrink-0 ${prefixColorClass}`}>
          {React.string(displayPrefix)}
        </span>
        <div className="flex items-center gap-1 text-[10px] min-w-0 overflow-hidden flex-1">
          {summaryLabels
          ->Array.mapWithIndex((label, i) => {
            <React.Fragment key={Int.toString(i)}>
              {i > 0 ? <span className="text-zinc-600"> {React.string(" · ")} </span> : React.null}
              <span className="text-zinc-300 truncate"> {React.string(label)} </span>
            </React.Fragment>
          })
          ->React.array}
        </div>
        <span className="text-[9px] text-zinc-500 bg-zinc-700/50 px-1 py-0.5 rounded shrink-0">
          {React.string(Int.toString(toolCount))}
        </span>
      </div>
      <div
        className={`frontman-collapse-transition
                    ${isExpanded ? "opacity-100 mt-0.5" : "max-h-0 opacity-0 overflow-hidden"}`}>
        <div className="pl-3 border-l border-zinc-600/30 space-y-0.5">
          {group.toolCalls->Array.mapWithIndex((tc, i) => {
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
              messageId={`${messageId}-${Int.toString(i)}`}
            />
          })->React.array}
        </div>
      </div>
    </div>
  }
}

@react.component
let make = (~group: Types.toolGroup, ~defaultExpanded: bool=false, ~isLastGroup: bool=false, ~messageId: string) => {
  // Check if any tool in the group is still loading
  let isLoading = group.toolCalls->Array.some(tc => {
    switch tc.state {
    | Client__State__Types.Message.InputStreaming
    | Client__State__Types.Message.InputAvailable => true
    | _ => false
    }
  })

  // Track if user has manually toggled expansion
  let hasUserToggled = React.useRef(false)
  
  // Ref for the scrollable container to auto-scroll
  let scrollContainerRef = React.useRef(Nullable.null)
  
  // Track tool count for auto-scroll detection
  let prevToolCount = React.useRef(Array.length(group.toolCalls))
  
  // Auto-expand if this is the last group and it's still loading
  let shouldAutoExpand = isLastGroup && isLoading
  let (isExpanded, setIsExpanded) = React.useState(() => defaultExpanded || shouldAutoExpand)
  
  // Raw JS helper for smooth scrolling to bottom
  let scrollToBottom: Dom.element => unit = %raw(`
    function(element) {
      element.scrollTo({ top: element.scrollHeight, behavior: 'smooth' });
    }
  `)
  
  // Auto-scroll to bottom when new tools are added to the last group
  React.useEffect2(() => {
    let currentCount = Array.length(group.toolCalls)
    if isLastGroup && isExpanded && currentCount > prevToolCount.current {
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

  // Get dynamic prefix (Exploring/Explored based on loading state)
  let displayPrefix = Utils.getGroupPrefix(group)

  // Toggle expansion - mark as user-toggled to prevent auto-expand interference
  let handleToggle = _ => {
    hasUserToggled.current = true
    setIsExpanded(prev => !prev)
  }

  // Style variants for subagent vs main agent groups - borderless design
  let headerBgClass = if isSubagent {
    "bg-indigo-950/50 hover:bg-indigo-900/50"
  } else {
    "bg-zinc-800/70 hover:bg-zinc-700/50"
  }

  let borderLineClass = if isSubagent {
    "border-indigo-600/40"
  } else {
    "border-zinc-600/40"
  }

  let prefixColorClass = if isSubagent {
    if isLoading { "shimmer-text" } else { "text-indigo-400" }
  } else {
    if isLoading { "shimmer-text" } else { "text-zinc-400" }
  }

  <div className="my-1.5 animate-in fade-in duration-100">
    // Collapsed Summary Header - borderless
    <div
      className={`group flex items-center gap-1.5 px-2 py-1.5 rounded-md cursor-pointer 
                  transition-colors duration-150 ${headerBgClass}`}
      onClick={handleToggle}>
      // Expand/Collapse Chevron (left side)
      <button
        type_="button"
        className="flex items-center justify-center w-4 h-4 shrink-0
                   text-zinc-500 transition-transform duration-200">
        <Icons.ChevronDownIcon size=10 className={isExpanded ? "rotate-180" : "-rotate-90"} />
      </button>
      // Subagent icon (for subagent groups)
      {isSubagent
        ? <svg
            className="w-3 h-3 text-indigo-400 shrink-0"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2">
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
          {React.string(toolName)}
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
      <span
        className="text-[10px] text-zinc-500 bg-zinc-700/50 px-1.5 py-0.5 rounded shrink-0">
        {React.string(Int.toString(toolCount))}
      </span>
    </div>
    // Expanded Children - scrollable with max height
    // For subagent groups, apply internal grouping to show nested "Explored" groups
    {
      let renderContent = if isSubagent {
        // Apply grouping to subagent tool calls
        // Pass ~groupSubagents=false so tool calls are grouped by type (read vs write)
        // instead of all being lumped together as a single subagent group
        let groupedItems = Utils.groupToolCalls(group.toolCalls, ~minGroupSize=2, ~groupSubagents=false)
        groupedItems->Array.mapWithIndex((item, i) => {
          let key = `${messageId}-${Int.toString(i)}`
          switch item {
          | Types.SingleTool(tc) =>
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
              messageId={key}
            />
          | Types.SpawnerTool(tc) =>
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
              isSpawner=true
              messageId={key}
            />
          | Types.ToolGroup(nestedGroup) =>
            // Render nested group (e.g., "Explored 3 files" within subagent)
            <NestedToolGroup key={nestedGroup.id} group={nestedGroup} messageId={key} />
          }
        })->React.array
      } else {
        // Regular groups - render tool calls directly
        group.toolCalls->Array.mapWithIndex((tc, i) => {
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
            messageId={`${messageId}-${Int.toString(i)}`}
          />
        })->React.array
      }
      
      <div
        className={`frontman-collapse-transition
                    ${isExpanded ? "opacity-100 mt-1" : "max-h-0 opacity-0 overflow-hidden"}`}>
        <div 
          ref={ReactDOM.Ref.domRef(scrollContainerRef)}
          className={`pl-4 border-l-2 space-y-0.5 max-h-[150px] overflow-y-auto scroll-smooth ${borderLineClass}`}>
          {renderContent}
        </div>
      </div>
    }
  </div>
}

