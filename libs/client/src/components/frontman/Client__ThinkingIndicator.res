/**
 * ThinkingIndicator - Minimal shimmer "Thinking" indicator
 * 
 * Shows a simple inline indicator while the AI is thinking.
 */
type displayState = Hidden | Showing | FadingOut

@react.component
let make = (
  ~show: bool,
  ~context: option<string>=?,
  ~content as _: option<string>=?,
  ~messageId as _: string,
) => {
  let (displayState, setDisplayState) = React.useState(() =>
    if show {
      Showing
    } else {
      Hidden
    }
  )
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
    let anim =
      displayState == Showing
        ? "animate-in fade-in duration-100"
        : "animate-out fade-out duration-300"

    <div className={`my-1.5 mx-3 ${anim}`}>
      <span className="shimmer-text text-[13px] text-violet-300/70">
        {React.string(context->Option.getOr("Thinking..."))}
      </span>
    </div>
  }
}
