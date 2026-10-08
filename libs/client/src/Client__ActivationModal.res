module State = Client__State
module Billing = Client__Billing
module Dialog = Client__UI__Dialog
module Button = Client__UI__Button

@react.component
let make = (~open_: bool) => {
  let status = State.useSelector(State.Selectors.billingStatus)
  let flow = State.useSelector(State.Selectors.billingFlow)
  let draft = State.useSelector(State.Selectors.composerDraft)
  let connected = State.useSelector(State.Selectors.hasActiveACPSession)
  let providerSetupRequired = State.useSelector(State.Selectors.providerSetupRequired)
  let selectedModel = State.useSelector(State.Selectors.selectedModelValue)
  let (interval, setInterval) = React.useState(() => Billing.Monthly)
  let opening = flow == Billing.Opening
  let providerReady = !providerSetupRequired && selectedModel->Option.isSome
  let (title, description) = switch status {
  | Loaded(status) if Billing.isAccessAllowed(status) => (
      switch Billing.subscriptionStatus(status) {
      | Trialing => "Your trial is active."
      | _ => "Your plan is active."
      },
      switch providerReady {
      | true => "Review your request before sending."
      | false => "Connect your AI account or API key. Usage is billed separately."
      },
    )
  | Loaded(_) if flow == Billing.AwaitingCheckout => (
      "Complete checkout in the new tab.",
      "Your plan updates here after activation is confirmed.",
    )
  | Loaded(status) if Billing.needsPaymentRecovery(status) => (
      "Update your payment method.",
      "Restore access to Frontman.",
    )
  | _ => ("Start shipping faster with Frontman pro", "Make changes directly on your website.")
  }

  <Dialog
    open_
    onOpenChange={(open_, _) =>
      switch open_ {
      | false => State.Actions.closeSettingsModal()
      | true => ()
      }}
  >
    <Dialog.Content className="sm:max-w-lg max-h-[90dvh] overflow-y-auto p-6 gap-5">
      <Dialog.Header className="pr-6">
        <Dialog.Title className="text-2xl font-semibold leading-tight text-balance">
          {React.string(title)}
        </Dialog.Title>
        <Dialog.Description> {React.string(description)} </Dialog.Description>
      </Dialog.Header>
      {switch draft->String.trim {
      | "" => React.null
      | _ =>
        <div className="space-y-1 border-b pb-5">
          <p className="text-xs text-muted-foreground"> {React.string("Your request")} </p>
          <p className="text-sm whitespace-pre-wrap break-words max-h-16 overflow-y-auto">
            {React.string(draft)}
          </p>
        </div>
      }}
      {switch flow {
      | Failed(error) =>
        <p role="alert" className="text-sm text-destructive"> {React.string(error)} </p>
      | _ => React.null
      }}
      {switch status {
      | NotLoaded | Error(_) =>
        <div className="space-y-3" role="status">
          <p>
            {React.string(
              switch status {
              | Error(_) => "We couldn't check your plan. Please retry."
              | _ => "Checking your plan..."
              },
            )}
          </p>
          <Button
            className="w-full min-h-11"
            variant=Button.Variant.Secondary
            disabled={!connected}
            onClick={_ => State.Actions.requestBilling(Status)}
          >
            {React.string("Retry plan check")}
          </Button>
        </div>
      | Loaded(status) if Billing.isAccessAllowed(status) =>
        <div role="status">
          <p className="sr-only"> {React.string(title)} </p>
          <Button
            className="w-full min-h-11"
            disabled={!connected}
            onClick={_ => State.Actions.continueActivation()}
          >
            {React.string(
              switch providerReady {
              | true => "Review my request"
              | false => "Connect my AI provider"
              },
            )}
          </Button>
        </div>
      | Loaded(_) if flow == Billing.AwaitingCheckout =>
        <div className="space-y-2" role="status">
          <Button
            className="w-full min-h-11"
            disabled={!connected}
            onClick={_ => State.Actions.requestBilling(Status)}
          >
            {React.string("Check activation")}
          </Button>
          <Button
            className="w-full min-h-11"
            variant=Button.Variant.Ghost
            onClick={_ => State.Actions.dismissBillingCheckout()}
          >
            {React.string("Canceled checkout? Back to your offer")}
          </Button>
        </div>
      | Loaded(status) if Billing.needsPaymentRecovery(status) =>
        <Button
          className="w-full min-h-11"
          disabled={opening || !connected}
          onClick={_ => State.Actions.requestBilling(CustomerPortal)}
        >
          {React.string(
            switch opening {
            | true => "Opening Stripe..."
            | false => "Update payment method"
            },
          )}
        </Button>
      | Loaded(status) =>
        let trialDays = Billing.offeredTrialDays(status)
        <div className="space-y-5">
          <fieldset>
            <legend className="sr-only"> {React.string("Billing frequency")} </legend>
            <div className="grid grid-cols-2 gap-2">
              {[Billing.Monthly, Billing.Yearly]
              ->Array.map(option =>
                <label
                  key={Billing.intervalLabel(option)}
                  className={`flex min-h-11 items-center gap-3 rounded-lg border p-3 cursor-pointer focus-within:ring-2 focus-within:ring-ring/50 ${switch interval ==
                      option {
                    | true => "border-primary bg-primary/5"
                    | false => "hover:bg-muted"
                    }}`}
                >
                  <input
                    type_="radio"
                    name="activation-interval"
                    ariaLabel={Billing.intervalLabel(option)}
                    checked={interval == option}
                    onChange={_ => setInterval(_ => option)}
                    className="accent-primary size-4"
                  />
                  <span className="flex flex-col">
                    <span className="font-medium">
                      {React.string(Billing.intervalLabel(option))}
                    </span>
                    {switch option {
                    | Monthly => React.null
                    | Yearly =>
                      <span className="text-xs text-muted-foreground">
                        {React.string("Save €30 / year")}
                      </span>
                    }}
                  </span>
                </label>
              )
              ->React.array}
            </div>
          </fieldset>
          <div className="space-y-1">
            <p className="text-2xl font-semibold"> {React.string(Billing.priceLabel(interval))} </p>
            {switch interval {
            | Monthly => React.null
            | Yearly =>
              <p className="text-sm text-muted-foreground">
                {React.string("€12.50 / month equivalent")}
              </p>
            }}
            <p className="text-sm text-muted-foreground">
              {React.string(
                switch trialDays {
                | Some(days) => `${Int.toString(days)} days free, then auto-renews unless canceled.`
                | None => "Auto-renews unless canceled."
                },
              )}
            </p>
          </div>
          <div className="space-y-3">
            <p className="text-xs leading-relaxed text-muted-foreground">
              {React.string(
                "Card required. AI account or API key required; provider usage billed separately. Taxes may apply.",
              )}
            </p>
            <Button
              className="w-full min-h-11"
              disabled={opening || !connected}
              onClick={_ => State.Actions.requestBilling(Checkout(interval))}
            >
              {React.string(
                switch (opening, trialDays) {
                | (true, _) => "Opening checkout..."
                | (false, Some(days)) => `Start ${Int.toString(days)}-day trial`
                | _ => "Continue to checkout"
                },
              )}
            </Button>
            <p className="text-xs text-center text-muted-foreground">
              {React.string("Stripe Checkout opens in a new tab.")}
            </p>
          </div>
        </div>
      }}
      {switch connected {
      | false =>
        <p role="status" className="text-sm text-muted-foreground">
          {React.string("Reconnect to continue. Your draft remains in this tab.")}
        </p>
      | true => React.null
      }}
      <Button
        variant=Button.Variant.Ghost
        className="min-h-11"
        onClick={_ => State.Actions.closeSettingsModal()}
      >
        {React.string("Back to my request")}
      </Button>
    </Dialog.Content>
  </Dialog>
}
