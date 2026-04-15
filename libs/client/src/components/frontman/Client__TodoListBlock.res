/**
 * TodoListBlock - Renders a TODO list within the chat stream
 * 
 * Shows todos in a compact inline format with status icons and content.
 * Completed/cancelled items have strikethrough text.
 */
module Icons = Client__ToolIcons
module TodoUtils = Client__TodoUtils

@react.component
let make = (~todos: array<TodoUtils.todoItem>, ~isLoading: bool=false, ~messageId as _: string) => {
  // For single todo, show ultra-compact inline format
  let isSingleTodo = Array.length(todos) == 1

  // Get icon and colors based on status
  let getStatusIcon = (status: [#pending | #in_progress | #completed | #cancelled]) => {
    switch status {
    | #pending => (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 16 16"
          fill="currentColor"
          width="12"
          height="12"
        >
          <circle cx="8" cy="8" r="6" stroke="currentColor" strokeWidth="1.5" fill="none" />
        </svg>,
        "text-zinc-500",
      )
    | #in_progress => (<Icons.LoaderIcon size=12 />, "text-blue-400")
    | #completed => (<Icons.CheckIcon size=12 />, "text-teal-400")
    | #cancelled => (<Icons.XIcon size=12 />, "text-red-400")
    }
  }

  // Render a compact todo item inline
  let renderCompactTodo = (todo: TodoUtils.todoItem) => {
    let (icon, iconColor) = getStatusIcon(todo.status)
    let isDone = todo.status == #completed || todo.status == #cancelled

    <div key={todo.id} className="flex items-center gap-1.5 min-w-0">
      <span className={`shrink-0 w-3 h-3 ${iconColor}`}> {icon} </span>
      <span
        className={isDone
          ? "text-xs text-zinc-500 line-through truncate"
          : "text-xs text-zinc-300 truncate"}
      >
        {React.string(todo.content)}
      </span>
    </div>
  }

  // For single todo or loading, show ultra-compact single line
  if isSingleTodo && !isLoading {
    let todo = todos->Array.getUnsafe(0)
    <div
      className="flex items-center gap-2 px-2 py-1.5 bg-zinc-800 border border-zinc-700 rounded-md my-1 animate-in fade-in duration-100"
    >
      {renderCompactTodo(todo)}
    </div>
  } else if Array.length(todos) > 0 {
    // Multiple todos - show compact list
    <div
      className="bg-zinc-800 border border-zinc-700 rounded-md my-1 animate-in fade-in duration-100 overflow-hidden"
    >
      <div className="flex flex-col gap-0.5 p-2">
        {todos->Array.map(todo => renderCompactTodo(todo))->React.array}
      </div>
    </div>
  } else {
    React.null
  }
}
