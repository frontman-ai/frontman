module Button = Client__UI__Button
module Dialog = Client__UI__Dialog

@react.component
let make = (~open_: bool, ~onOpenSettings: unit => unit) => {
  let wasOpen = React.useRef(false)

  React.useEffect(() => {
    switch (wasOpen.current, open_) {
    | (false, true) =>
      Client__State.Actions.trackActivationEvent(Client__Heap.ProviderSetupBlockerShown)
    | _ => ()
    }
    wasOpen.current = open_
    None
  }, [open_])

  <Dialog open_ onOpenChange={(_, _) => ()}>
    <Dialog.Content className="sm:max-w-md" showCloseButton=false>
      <Dialog.Header>
        <Dialog.Title> {React.string("One last step, then you're ready to build")} </Dialog.Title>
        <Dialog.Description>
          {React.string(
            "Frontman uses an AI provider to understand your requests and generate code. Connect one you already use, choose your model, and stay in control of billing.",
          )}
        </Dialog.Description>
      </Dialog.Header>
      <ol className="space-y-3 py-1 text-sm">
        {[
          "Choose a provider you already use",
          "Connect your account or add an API key",
          "Pick a model and start building",
        ]
        ->Array.mapWithIndex((instruction, index) =>
          <li key={instruction} className="flex items-center gap-3">
            <span
              className="flex size-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-medium text-muted-foreground"
            >
              {React.int(index + 1)}
            </span>
            <span className="text-foreground/90"> {React.string(instruction)} </span>
          </li>
        )
        ->React.array}
      </ol>
      <Dialog.Footer>
        <Button className="w-full sm:w-auto" onClick={_ => onOpenSettings()}>
          {React.string("Connect AI provider")}
        </Button>
      </Dialog.Footer>
    </Dialog.Content>
  </Dialog>
}
