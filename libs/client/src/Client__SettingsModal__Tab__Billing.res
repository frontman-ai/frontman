module Badge = Client__UI__Badge
module Button = Client__UI__Button
module Card = Client__UI__Card
module Spinner = Client__UI__Spinner
module State = Client__State
module Types = Client__State__Types

let statusLabel = status =>
  switch status {
  | Types.NoSubscription => "No active plan"
  | Types.Trialing => "Trialing"
  | Types.Active => "Active"
  | Types.PastDue => "Past due"
  | Types.Canceled => "canceled"
  | Types.Incomplete => "incomplete"
  | Types.IncompleteExpired => "incomplete_expired"
  | Types.Unpaid => "unpaid"
  | Types.UnknownSubscriptionStatus(status) => status
  }

let statusVariant = status =>
  switch status {
  | Types.Trialing | Types.Active => Badge.Variant.Emerald
  | Types.PastDue => Badge.Variant.Amber
  | Types.NoSubscription => Badge.Variant.Zinc
  | Types.Canceled
  | Types.Incomplete
  | Types.IncompleteExpired
  | Types.Unpaid
  | Types.UnknownSubscriptionStatus(_) =>
    Badge.Variant.Red
  }

let intervalLabel = interval =>
  switch interval {
  | Types.Monthly => "Monthly"
  | Types.Yearly => "Yearly"
  }

let checkoutIntervalIsLoading = (~checkoutState, ~interval) =>
  switch checkoutState {
  | Types.BillingCheckoutLoading(loadingInterval) => loadingInterval == interval
  | Types.BillingCheckoutIdle | Types.BillingCheckoutError(_) => false
  }

let formatDate = value => {
  let date = Date.fromString(value)
  Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(date)
}

let renderDetailRow = (~label, ~value) =>
  <div className="flex items-center justify-between gap-4 py-2 text-sm">
    <span className="text-muted-foreground"> {React.string(label)} </span>
    <span className="text-right font-medium"> {React.string(value)} </span>
  </div>

let renderOptionalDetailRow = (~label, value) =>
  switch value {
  | Some(value) => renderDetailRow(~label, ~value=formatDate(value))
  | None => React.null
  }

let renderCheckoutButton = (
  ~interval,
  ~label,
  ~loadingLabel,
  ~checkoutState,
  ~variant=Button.Variant.Default,
) => {
  let loading = checkoutIntervalIsLoading(~checkoutState, ~interval)
  <Button
    variant
    className="w-full sm:w-40"
    disabled={switch checkoutState {
    | Types.BillingCheckoutLoading(_) => true
    | Types.BillingCheckoutIdle | Types.BillingCheckoutError(_) => false
    }}
    onClick={_ => State.Actions.startBillingCheckout(~interval)}
  >
    {switch loading {
    | true => <Spinner dataIcon=Spinner.InlineStart />
    | false => React.null
    }}
    {React.string(
      switch loading {
      | true => loadingLabel
      | false => label
      },
    )}
  </Button>
}

let renderCheckoutError = checkoutState =>
  switch checkoutState {
  | Types.BillingCheckoutError(error) =>
    <div
      role="alert" className="rounded-lg border border-destructive/30 p-2 text-sm text-destructive"
    >
      {React.string(error)}
    </div>
  | Types.BillingCheckoutIdle | Types.BillingCheckoutLoading(_) => React.null
  }

let renderCheckoutOption = (
  ~interval,
  ~title,
  ~price,
  ~description,
  ~loadingLabel,
  ~checkoutState,
  ~variant,
  ~badge=?,
) =>
  <div
    className="grid gap-3 py-3 first:pt-0 last:pb-0 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
  >
    <div className="space-y-1">
      <div className="flex items-center gap-2">
        <span className="text-sm font-medium"> {React.string(title)} </span>
        {switch badge {
        | Some(badge) => <Badge variant=Badge.Variant.Emerald> {React.string(badge)} </Badge>
        | None => React.null
        }}
      </div>
      <div className="text-base font-semibold tracking-tight"> {React.string(price)} </div>
      <p className="text-xs text-muted-foreground"> {React.string(description)} </p>
    </div>
    {renderCheckoutButton(
      ~interval,
      ~label=`Choose ${title}`,
      ~loadingLabel,
      ~checkoutState,
      ~variant,
    )}
  </div>

let renderCheckoutActions = (~checkoutState) => {
  <>
    <div className="divide-y">
      {renderCheckoutOption(
        ~interval=Types.CheckoutYearly,
        ~title="Yearly",
        ~price="EUR 12.50 / seat / month",
        ~description="EUR 150 billed once per year. Saves EUR 30.",
        ~loadingLabel="Starting yearly...",
        ~checkoutState,
        ~variant=Button.Variant.Default,
        ~badge="Best value",
      )}
      {renderCheckoutOption(
        ~interval=Types.CheckoutMonthly,
        ~title="Monthly",
        ~price="EUR 15 / seat / month",
        ~description="EUR 15 billed monthly.",
        ~loadingLabel="Starting monthly...",
        ~checkoutState,
        ~variant=Button.Variant.Secondary,
      )}
    </div>
    {renderCheckoutError(checkoutState)}
  </>
}

let renderLoaded = (~checkoutState, billingStatus: Types.billingStatus) =>
  <Card size=Card.Size.Sm>
    <Card.Header>
      <Card.Action>
        <Badge variant={statusVariant(billingStatus.status)}>
          {React.string(statusLabel(billingStatus.status))}
        </Badge>
      </Card.Action>
      <Card.Title> {React.string("Plan status")} </Card.Title>
      <Card.Description>
        {React.string("Stripe manages payment methods, invoices, and cancellation.")}
      </Card.Description>
    </Card.Header>
    <Card.Content className="space-y-4">
      <div className="divide-y">
        {switch billingStatus.interval {
        | Some(interval) => renderDetailRow(~label="Interval", ~value=intervalLabel(interval))
        | None => React.null
        }}
        {renderOptionalDetailRow(~label="Current period end", billingStatus.currentPeriodEnd)}
        {renderOptionalDetailRow(~label="Trial end", billingStatus.trialEnd)}
        {renderOptionalDetailRow(~label="Cancel date", billingStatus.cancelAt)}
        {renderOptionalDetailRow(~label="Canceled date", billingStatus.canceledAt)}
      </div>
      {switch billingStatus.accessAllowed {
      | true => React.null
      | false => renderCheckoutActions(~checkoutState)
      }}
    </Card.Content>
  </Card>

let renderLoading = () =>
  <Card size=Card.Size.Sm>
    <Card.Content className="flex items-center gap-2 text-sm text-muted-foreground">
      <Spinner dataIcon=Spinner.InlineStart />
      {React.string("Checking billing...")}
    </Card.Content>
  </Card>

@react.component
let make = () => {
  let billingStatus = State.useSelector(State.Selectors.billingStatus)
  let billingCheckout = State.useSelector(State.Selectors.billingCheckout)

  {
    switch billingStatus {
    | Types.BillingStatusNotLoaded | Types.BillingStatusLoading => renderLoading()
    | Types.BillingStatusLoaded(billingStatus) =>
      renderLoaded(~checkoutState=billingCheckout, billingStatus)
    | Types.BillingStatusError(error) =>
      <div role="alert" className="text-sm text-destructive"> {React.string(error)} </div>
    }
  }
}
