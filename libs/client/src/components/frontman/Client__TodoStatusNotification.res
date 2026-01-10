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
module Todo = Client__State__Types.Todo

@react.component
let make = (~content: string, ~status: Todo.status) => {
  let (icon, iconColor, labelText, textColor) = switch status {
  | Todo.Pending => (
      // Clock icon for pending
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        fill="currentColor"
        width="12"
        height="12">
        <path d="M8 2a6 6 0 100 12A6 6 0 008 2zm.75 3a.75.75 0 00-1.5 0v3c0 .414.336.75.75.75h2a.75.75 0 000-1.5H8.75V5z" />
      </svg>,
      "text-zinc-400",
      "Pending",
      "text-zinc-300",
    )
  | Todo.InProgress => (
      // Play/arrow icon for in progress
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
      "In Progress",
      "text-blue-300",
    )
  | Todo.Completed => (
      <Icons.CheckIcon size=12 />,
      "text-teal-400",
      "Completed",
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
