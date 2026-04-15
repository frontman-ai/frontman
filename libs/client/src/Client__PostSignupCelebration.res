// Post-signup celebration overlay
// Fires confetti and shows a congratulatory message with CTA to connect a provider

module Button = Bindings__UI__Button

let autoDismissMs = 8000

@react.component
let make = (~onDismiss: unit => unit, ~onConnectProvider: unit => unit) => {
  let (visible, setVisible) = React.useState(() => true)

  // Fire confetti on mount
  React.useEffect0(() => {
    // Fire all bursts simultaneously — canvas-confetti promises resolve only after
    // particles fully fade (~3-5s), so awaiting them sequentially would cause ~9-15s delays.
    Bindings__CanvasConfetti.fire({
      particleCount: 80,
      spread: 70,
      origin: {x: 0.5, y: 0.4},
      colors: ["#a78bfa", "#818cf8", "#6366f1", "#c084fc", "#e879f9"],
      disableForReducedMotion: true,
    })->ignore
    Bindings__CanvasConfetti.fire({
      particleCount: 40,
      angle: 60,
      spread: 55,
      origin: {x: 0.0, y: 0.6},
      colors: ["#a78bfa", "#818cf8", "#6366f1"],
      disableForReducedMotion: true,
    })->ignore
    Bindings__CanvasConfetti.fire({
      particleCount: 40,
      angle: 120,
      spread: 55,
      origin: {x: 1.0, y: 0.6},
      colors: ["#c084fc", "#e879f9", "#6366f1"],
      disableForReducedMotion: true,
    })->ignore
    None
  })

  // Auto-dismiss after timeout
  React.useEffect0(() => {
    let id = WebAPI.Global.setTimeout(~handler=() => {
      setVisible(_ => false)
      onDismiss()
    }, ~timeout=autoDismissMs)

    Some(() => WebAPI.Global.clearTimeout(id))
  })

  let handleConnectProvider = () => {
    setVisible(_ => false)
    onConnectProvider()
  }

  let handleSkip = () => {
    setVisible(_ => false)
    onDismiss()
  }

  switch visible {
  | false => React.null
  | true =>
    // Full-screen overlay with centered card
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 animate-in fade-in duration-300"
      onClick={_ => handleSkip()}
    >
      <div
        className="relative mx-4 w-full max-w-sm rounded-xl border border-zinc-700 bg-zinc-900 p-8 text-center shadow-2xl animate-in zoom-in-95 fade-in duration-300"
        onClick={e => ReactEvent.Mouse.stopPropagation(e)}
      >
        // Success icon
        <div
          className="mx-auto mb-5 flex size-14 items-center justify-center rounded-full bg-gradient-to-br from-violet-500/20 to-indigo-500/20 ring-1 ring-violet-500/30"
        >
          <svg
            className="size-7 text-violet-400"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth="2"
            stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
        </div>
        <h2 className="text-lg font-bold text-zinc-100"> {React.string("You're all set!")} </h2>
        <p className="mt-2 text-sm text-zinc-400 leading-relaxed">
          {React.string(
            "Welcome to Frontman. Connect your AI provider to start building with your coding assistant.",
          )}
        </p>
        <div className="mt-6 space-y-3">
          <Button.Button
            className="w-full bg-violet-600 text-white hover:bg-violet-500"
            onClick={_ => handleConnectProvider()}
          >
            {React.string("Connect AI Provider")}
          </Button.Button>
          <button
            type_="button"
            className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors cursor-pointer"
            onClick={_ => handleSkip()}
          >
            {React.string("Skip for now")}
          </button>
        </div>
      </div>
    </div>
  }
}
