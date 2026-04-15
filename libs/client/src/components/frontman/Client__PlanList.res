/**
 * Client__PlanList - Plan entries display component
 * 
 * Pure ReScript replacement for Queue components.
 * Displays a collapsible list of plan entries with status indicators.
 */
module Icons = Client__ToolIcons
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

// Status helpers
let statusToCompleted = (status: ACPTypes.planEntryStatus): bool => {
  switch status {
  | Completed => true
  | Pending | InProgress => false
  }
}

let statusToInProgress = (status: ACPTypes.planEntryStatus): bool => {
  switch status {
  | InProgress => true
  | Pending | Completed => false
  }
}

// Individual plan item component
module PlanItem = {
  @react.component
  let make = (~entry: ACPTypes.planEntry, ~index: int) => {
    let isCompleted = statusToCompleted(entry.status)
    let isInProgress = statusToInProgress(entry.status)

    let containerClasses =
      ["flex items-center gap-2 py-1.5 px-2 rounded", isInProgress ? "bg-blue-950/30" : ""]
      ->Array.filter(s => s != "")
      ->Array.join(" ")

    let indicatorClasses =
      [
        "flex items-center justify-center w-4 h-4 shrink-0 rounded-full",
        isCompleted ? "text-teal-400" : "text-zinc-500",
      ]->Array.join(" ")

    let contentClasses =
      [
        "text-xs flex-1 min-w-0",
        isCompleted ? "text-zinc-500 line-through" : "text-zinc-200",
      ]->Array.join(" ")

    <div key={`plan-entry-${index->Int.toString}`} className={containerClasses}>
      <span className={indicatorClasses}>
        {isCompleted
          ? <Icons.CheckIcon size=12 />
          : isInProgress
          ? <Icons.LoaderIcon size=12 />
          : <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 16 16"
              fill="currentColor"
              width="12"
              height="12"
            >
              <circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5" fill="none" />
            </svg>}
      </span>
      <span className={contentClasses}> {React.string(entry.content)} </span>
    </div>
  }
}

@react.component
let make = (~entries: array<ACPTypes.planEntry>) => {
  let (isExpanded, setIsExpanded) = React.useState(() => true)

  if Array.length(entries) == 0 {
    React.null
  } else {
    let completedCount = entries->Array.filter(e => e.status == Completed)->Array.length
    let totalCount = Array.length(entries)

    <div className="mb-4 bg-zinc-800/50 border border-zinc-700/50 rounded-lg overflow-hidden">
      // Header
      <button
        type_="button"
        onClick={_ => setIsExpanded(prev => !prev)}
        className="w-full flex items-center justify-between gap-2 px-3 py-2 
                   hover:bg-zinc-700/30 transition-colors cursor-pointer"
      >
        <div className="flex items-center gap-2">
          <Icons.ChevronDownIcon
            size=14
            className={`text-zinc-400 transition-transform duration-200 ${isExpanded
                ? ""
                : "-rotate-90"}`}
          />
          <span className="text-xs font-medium text-zinc-300">
            {React.string(`Plan (${completedCount->Int.toString}/${totalCount->Int.toString})`)}
          </span>
        </div>
        // Progress indicator
        <div className="flex items-center gap-2">
          <div className="w-16 h-1.5 bg-zinc-700 rounded-full overflow-hidden">
            <div
              className="h-full bg-teal-500 transition-all duration-300"
              style={{
                width: `${(Float.fromInt(completedCount) /. Float.fromInt(totalCount) *. 100.0)
                    ->Float.toString}%`,
              }}
            />
          </div>
        </div>
      </button>

      // Content
      <div
        className={`frontman-collapse-transition ${isExpanded
            ? "opacity-100"
            : "max-h-0 opacity-0 overflow-hidden"}`}
      >
        <div className="px-2 pb-2 space-y-0.5">
          {entries
          ->Array.mapWithIndex((entry, index) => {
            <PlanItem key={`plan-${index->Int.toString}`} entry index />
          })
          ->React.array}
        </div>
      </div>
    </div>
  }
}
