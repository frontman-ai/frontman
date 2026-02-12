/**
 * MessageContainer - Base wrapper for chat messages with animations
 */

@react.component
let make = (~isNew: bool=false, ~isStreaming: bool=false, ~className: string="", ~children: React.element) => {
  let classes = [
    "py-2 px-3 bg-fm-surface",
    isNew ? "animate-in fade-in duration-100" : "",
    isStreaming ? "bg-gradient-to-br from-fm-surface to-fm-accent-subtle" : "",
    className,
  ]->Array.filter(s => s != "")->Array.join(" ")

  <div className=classes>{children}</div>
}
