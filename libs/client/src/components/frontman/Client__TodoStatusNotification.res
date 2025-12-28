/**
 * TodoStatusNotification - Inline notification for todo status changes
 * 
 * Renders inline notifications like:
 * [play icon] Starting: Analyze codebase structure  
 * [check icon] Finished: Implement authentication
 * 
 * These appear in the chat stream to indicate progress on todos.
 */

module Icons = Client__ToolIcons
module StateTypes = Client__State__Types

@react.component
let make = (
  ~content: string,
  ~eventType: StateTypes.TodoStatusEvent.eventType,
  ~messageId as _: string,
) => {
  let (icon, iconColor, labelText, textColor) = switch eventType {
  | #started => (
      // Play/arrow icon for starting
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        fill="currentColor"
        width="12"
        height="12">
        <path
          d="M5.25 3.667c0-.735.817-1.177 1.424-.77l5.107 3.332a.934.934 0 010 1.542L6.674 11.103a.934.934 0 01-1.424-.77V3.668z"
        />
      </svg>,
      "text-blue-400",
      "Starting",
      "text-blue-300",
    )
  | #completed => (
      <Icons.CheckIcon size=12 />,
      "text-teal-400",
      "Finished",
      "text-teal-300",
    )
  }

  <div
    className="flex items-center gap-2 px-3 py-1.5 my-1 rounded-md bg-zinc-800/50 border border-zinc-700/40 animate-in fade-in slide-in-from-left-2 duration-200">
    // Status icon
    <span className={`shrink-0 w-3 h-3 flex items-center justify-center ${iconColor}`}>
      {icon}
    </span>
    // Label and content
    <div className="flex items-center gap-1.5 min-w-0 text-xs">
      <span className={`font-medium shrink-0 ${textColor}`}>
        {React.string(labelText ++ ":")}
      </span>
      <span className="text-zinc-300 truncate"> {React.string(content)} </span>
    </div>
  </div>
}
