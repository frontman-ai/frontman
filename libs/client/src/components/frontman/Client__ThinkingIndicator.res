/**
 * ThinkingIndicator - Shimmer loading state with fade transitions
 */

type displayState = Hidden | Showing | FadingOut

@react.component
let make = (~show: bool, ~context: option<string>=?, ~messageId as _: string) => {
  let (displayState, setDisplayState) = React.useState(() => if show { Showing } else { Hidden })
  let (wasEverShown, setWasEverShown) = React.useState(() => show)
  
  React.useEffect(() => {
    if show {
      setWasEverShown(_ => true)
      setDisplayState(_ => Showing)
      None
    } else if wasEverShown {
      setDisplayState(_ => FadingOut)
      let timer = Js.Global.setTimeout(() => setDisplayState(_ => Hidden), 300)
      Some(() => Js.Global.clearTimeout(timer))
    } else {
      setDisplayState(_ => Hidden)
      None
    }
  }, (show, wasEverShown))
  
  if displayState == Hidden {
    React.null
  } else {
    let anim = displayState == Showing ? "animate-in fade-in duration-100" : "animate-out fade-out duration-300"
    <div className={`flex items-center gap-2 py-3 px-4 text-[13px] text-zinc-400 ${anim}`}>
      <span className="shimmer-text">{React.string(context->Option.getOr("Thinking..."))}</span>
    </div>
  }
}
