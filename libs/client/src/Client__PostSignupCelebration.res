// Post-signup celebration overlay
// Fires confetti and shows a congratulatory message with CTA to connect a provider

module Button = Client__UI__Button
module Dialog = Client__UI__Dialog
module Icons = Client__UI__Icons

let autoDismissMs = 8000

@react.component
let make = (~onDismiss: unit => unit, ~onConnectProvider: unit => unit) => {
  let (visible, setVisible) = React.useState(() => true)

  // Fire confetti on mount
  React.useEffect0(() => {
    // Fire all bursts simultaneously — canvas-confetti promises resolve only after
    // particles fully fade (~3-5s), so awaiting them sequentially would cause ~9-15s delays.
    FrontmanBindings.Bindings__CanvasConfetti.fire({
      particleCount: 80,
      spread: 70,
      origin: {x: 0.5, y: 0.4},
      colors: ["#a78bfa", "#818cf8", "#6366f1", "#c084fc", "#e879f9"],
      disableForReducedMotion: true,
    })->ignore
    FrontmanBindings.Bindings__CanvasConfetti.fire({
      particleCount: 40,
      angle: 60,
      spread: 55,
      origin: {x: 0.0, y: 0.6},
      colors: ["#a78bfa", "#818cf8", "#6366f1"],
      disableForReducedMotion: true,
    })->ignore
    FrontmanBindings.Bindings__CanvasConfetti.fire({
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

  <Dialog
    open_=visible
    onOpenChange={(open_, _) =>
      switch open_ {
      | true => ()
      | false => handleSkip()
      }}
  >
    <Dialog.Content className="max-w-sm text-center">
      <Dialog.Header>
        <Icons.CheckIcon className="mx-auto size-10 text-primary" />
        <Dialog.Title> {React.string("You're all set!")} </Dialog.Title>
        <Dialog.Description>
          {React.string(
            "Welcome to Frontman. Connect your AI provider to start building with your coding assistant.",
          )}
        </Dialog.Description>
      </Dialog.Header>
      <div className="space-y-2">
        <Button className="w-full" onClick={_ => handleConnectProvider()}>
          {React.string("Connect AI Provider")}
        </Button>
        <Button variant=Button.Variant.Link className="w-full" onClick={_ => handleSkip()}>
          {React.string("Skip for now")}
        </Button>
      </div>
    </Dialog.Content>
  </Dialog>
}
