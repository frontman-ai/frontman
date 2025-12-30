/**
 * TodoBatchBlock - Renders "Added X todos" with expand/collapse
 * 
 * Shows a collapsible summary of todos that were created as a batch.
 * When collapsed, shows "Added X todos".
 * When expanded, shows the list of todos with their status icons.
 */

module Icons = Client__ToolIcons
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

@react.component
let make = (
  ~entries: array<ACPTypes.todoBatchEntry>,
  ~count: int,
  ~createdAt as _: float,
  ~messageId as _: string,
) => {
  let (isExpanded, setIsExpanded) = React.useState(() => false)

  let handleToggle = _ => setIsExpanded(prev => !prev)

  // Get icon and color based on status
  let getStatusIcon = (status: string) => {
    switch status {
    | "pending" => (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          width="12"
          height="12">
          <circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5" fill="none" />
        </svg>,
        "text-zinc-500",
      )
    | "in_progress" => (<Icons.LoaderIcon size=12 />, "text-blue-400")
    | "completed" => (<Icons.CheckIcon size=12 />, "text-teal-400")
    | "cancelled" => (<Icons.XIcon size=12 />, "text-red-400")
    | _ => (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          width="12"
          height="12">
          <circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5" fill="none" />
        </svg>,
        "text-zinc-500",
      )
    }
  }

  // Render a single todo entry
  let renderTodoEntry = (entry: ACPTypes.todoBatchEntry, index: int) => {
    let (icon, iconColor) = getStatusIcon(entry.status)
    let isDone = entry.status == "completed" || entry.status == "cancelled"
    // Use active_form if available, fallback to content
    let displayContent = entry.activeForm->Option.getOr(entry.content)

    <div
      key={`${entry.id}-${Int.toString(index)}`}
      className="flex items-center gap-1.5 min-w-0 py-0.5">
      <span className={`shrink-0 w-3 h-3 ${iconColor}`}> {icon} </span>
      <span
        className={isDone
          ? "text-xs text-zinc-500 line-through truncate"
          : "text-xs text-zinc-300 truncate"}>
        {React.string(displayContent)}
      </span>
    </div>
  }

  // Summary text
  let summaryText = count == 1 ? "Added 1 todo" : `Added ${Int.toString(count)} todos`

  <div
    className="my-1 bg-zinc-800/70 border border-zinc-700/50 rounded-lg overflow-hidden animate-in fade-in duration-150">
    // Header - always visible
    <div
      className="group flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-zinc-700/50 transition-colors duration-150"
      onClick={handleToggle}>
      // Expand/collapse chevron
      <button
        type_="button"
        className="flex items-center justify-center w-4 h-4 shrink-0 text-zinc-500 transition-transform duration-150">
        <Icons.ChevronDownIcon
          size=10 className={isExpanded ? "rotate-0" : "-rotate-90"}
        />
      </button>
      // Todo icon
      <span className="shrink-0 text-emerald-400">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          width="14"
          height="14">
          <path
            fillRule="evenodd"
            d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
            clipRule="evenodd"
          />
        </svg>
      </span>
      // Summary text
      <span className="text-xs text-zinc-300 font-medium"> {React.string(summaryText)} </span>
      // Count badge
      <span
        className="ml-auto text-[10px] text-zinc-500 bg-zinc-700/60 px-1.5 py-0.5 rounded-full shrink-0">
        {React.string(Int.toString(count))}
      </span>
    </div>
    // Expandable content
    <div
      className={`frontman-collapse-transition border-t border-zinc-700/50
                  ${isExpanded ? "opacity-100 max-h-96" : "max-h-0 opacity-0 overflow-hidden"}`}>
      <div className="px-3 py-2 space-y-0.5">
        {entries->Array.mapWithIndex(renderTodoEntry)->React.array}
      </div>
    </div>
  </div>
}
