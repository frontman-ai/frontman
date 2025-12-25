/**
 * TodoItem - Individual TODO item with status icon
 */

module Icons = Client__ToolIcons

type todoStatus = [#pending | #in_progress | #completed | #cancelled]

@react.component
let make = (~content: string, ~status: todoStatus) => {
  let (icon, iconColor) = switch status {
  | #pending => (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" width="12" height="12">
        <circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5" fill="none"/>
      </svg>,
      "text-zinc-500"
    )
  | #in_progress => (<Icons.LoaderIcon size=12 />, "text-blue-400")
  | #completed => (<Icons.CheckIcon size=12 />, "text-teal-400")
  | #cancelled => (<Icons.XIcon size=12 />, "text-red-400")
  }
  
  let isDone = status == #completed || status == #cancelled
  
  <div className="flex items-start gap-1.5 py-0.5">
    <span className={`shrink-0 mt-0.5 w-3 h-3 ${iconColor}`}>{icon}</span>
    <span className={isDone ? "text-xs text-zinc-400 line-through" : "text-xs text-zinc-200"}>
      {React.string(content)}
    </span>
  </div>
}
