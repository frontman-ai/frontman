/**
 * ToolStatus - Status indicator for tool calls
 */

module Icons = Client__ToolIcons
module Message = Client__State__Types.Message

@react.component
let make = (~state: Message.toolCallState, ~compact: bool=false) => {
  let (icon, text, colorClass) = switch state {
  | InputStreaming => (<Icons.LoaderIcon size=12 />, "...", "text-zinc-400")
  | InputAvailable => (<span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />, "Executing...", "text-green-400")
  | OutputAvailable => (<Icons.CheckIcon size=12 />, "Done", "text-teal-400")
  | OutputError => (<Icons.XIcon size=12 />, "Error", "text-red-400")
  }
  
  <div className={`inline-flex items-center gap-1 text-[11px] ${colorClass}`}>
    {icon}
    {compact ? React.null : <span>{React.string(text)}</span>}
  </div>
}
