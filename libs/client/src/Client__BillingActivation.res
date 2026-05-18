module Button = Client__UI__Button
module Card = Client__UI__Card
module Icons = Client__UI__Icons
module Spinner = Client__UI__Spinner
module Billing = Client__Billing
module State = Client__State

let shell = children =>
  <div
    className="flex flex-1 min-h-0 w-full items-center justify-center bg-[#130d20] p-6 text-zinc-200"
  >
    <div className="w-full max-w-lg"> {children} </div>
  </div>

let openBilling = () => State.Actions.openSettingsModalOnBilling()

let renderActivationState = (billingStatus: Billing.state) => {
  switch billingStatus {
  | Billing.NotLoaded =>
    shell(
      <Card className="border-white/10 bg-white/[0.03] text-zinc-100 ring-white/10">
        <Card.Content className="flex items-center gap-3">
          <Spinner dataIcon=Spinner.InlineStart />
          <div className="space-y-1">
            <div className="text-sm font-medium"> {React.string("Checking billing access")} </div>
            <p className="text-sm text-zinc-400">
              {React.string("Frontman unlocks automatically once billing is active.")}
            </p>
          </div>
        </Card.Content>
      </Card>,
    )

  | Billing.Error(error) =>
    shell(
      <Card className="border-red-500/20 bg-red-950/20 text-zinc-100 ring-red-500/20">
        <Card.Header>
          <Card.Title className="text-red-200">
            {React.string("Billing status unavailable")}
          </Card.Title>
          <Card.Description className="text-red-200/80"> {React.string(error)} </Card.Description>
        </Card.Header>
        <Card.Content>
          <Button variant=Button.Variant.Secondary onClick={_ => openBilling()}>
            {React.string("Open billing settings")}
          </Button>
        </Card.Content>
      </Card>,
    )

  | Billing.Loaded(billingStatus) =>
    switch Billing.isAccessAllowed(billingStatus) {
    | true => React.null
    | false =>
      shell(
        <Card className="border-violet-400/20 bg-white/[0.03] text-zinc-100 ring-violet-400/20">
          <Card.Header>
            <Card.Action>
              <div className="rounded-full bg-violet-500/15 p-2 text-violet-300">
                <Icons.CreditCardIcon className="size-5" />
              </div>
            </Card.Action>
            <Card.Title> {React.string("Activate Frontman")} </Card.Title>
            <Card.Description className="text-zinc-400">
              {React.string(Billing.activationMessage(billingStatus))}
            </Card.Description>
          </Card.Header>
          <Card.Content className="space-y-4">
            <p className="text-sm text-zinc-400">
              {React.string(
                "Choose a plan in Billing settings. Chat and task creation stay locked until Stripe confirms access.",
              )}
            </p>
            <Button onClick={_ => openBilling()}> {React.string("Open billing settings")} </Button>
          </Card.Content>
        </Card>,
      )
    }
  }
}

let shouldRenderChildren = (~sessionInitialized, billingStatus: Billing.state) => {
  switch billingStatus {
  | Billing.Loaded(status) => Billing.isAccessAllowed(status)
  | Billing.NotLoaded | Billing.Error(_) => !sessionInitialized
  }
}

module Gate = {
  @react.component
  let make = (~children) => {
    let billingStatus = State.useSelector(State.Selectors.billingStatus)
    let sessionInitialized = State.useSelector(State.Selectors.sessionInitialized)

    switch shouldRenderChildren(~sessionInitialized, billingStatus) {
    | true => children
    | false => renderActivationState(billingStatus)
    }
  }
}
