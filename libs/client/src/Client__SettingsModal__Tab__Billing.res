module Alert = Client__UI__Alert
module Badge = Client__UI__Badge
module Button = Client__UI__Button
module Card = Client__UI__Card
module Spinner = Client__UI__Spinner
module Billing = Client__Billing
module State = Client__State

let statusVariant = status =>
  switch status {
  | Billing.Trialing | Billing.Active => Badge.Variant.Emerald
  | Billing.PastDue => Badge.Variant.Amber
  | Billing.NoSubscription => Badge.Variant.Zinc
  | Billing.Canceled
  | Billing.Incomplete
  | Billing.IncompleteExpired
  | Billing.Unpaid
  | Billing.UnknownSubscriptionStatus(_) =>
    Badge.Variant.Red
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

let renderButton = (~request, ~label, ~disabled, ~opening, ~variant) =>
  <Button variant disabled onClick={_ => State.Actions.requestBilling(request)}>
    {React.string(
      switch opening {
      | true => "Opening Stripe..."
      | false => label
      },
    )}
  </Button>

@react.component
let make = () => {
  let billingStatus = State.useSelector(State.Selectors.billingStatus)
  let billingFlow = State.useSelector(State.Selectors.billingFlow)
  let connected = State.useSelector(State.Selectors.hasActiveACPSession)
  let opening = billingFlow === Billing.Opening
  let disabled = opening || !connected

  <div className="space-y-4">
    {switch billingFlow {
    | Failed(error) =>
      <Alert className="border-destructive/30 text-destructive">
        <Alert.Title> {React.string("Could not open billing")} </Alert.Title>
        <Alert.Description> {React.string(error)} </Alert.Description>
      </Alert>
    | Idle | Opening => React.null
    }}
    {switch billingStatus {
    | NotLoaded =>
      <Card size=Card.Size.Sm>
        <Card.Content className="flex items-center gap-2 text-sm text-muted-foreground">
          <Spinner dataIcon=Spinner.InlineStart />
          {React.string("Checking billing...")}
        </Card.Content>
      </Card>
    | Error(error) => <div role="alert" className="text-destructive"> {React.string(error)} </div>
    | Loaded(status) =>
      <Card size=Card.Size.Sm>
        <Card.Header>
          <Card.Action>
            <Badge variant={statusVariant(Billing.subscriptionStatus(status))}>
              {React.string(Billing.statusLabel(status))}
            </Badge>
          </Card.Action>
          <Card.Title> {React.string("Plan status")} </Card.Title>
          <Card.Description>
            {React.string("Stripe manages payment methods, invoices, and cancellation.")}
          </Card.Description>
        </Card.Header>
        <Card.Content className="space-y-4">
          {switch Billing.cancelAt(status) {
          | Some(cancelAt) =>
            <Alert>
              <Alert.Title> {React.string("Subscription scheduled to cancel")} </Alert.Title>
              <Alert.Description>
                {React.string(`Access remains active until ${formatDate(cancelAt)}.`)}
              </Alert.Description>
            </Alert>
          | None => React.null
          }}
          <div className="divide-y">
            {switch Billing.interval(status) {
            | Some(interval) =>
              renderDetailRow(~label="Interval", ~value=Billing.intervalLabel(interval))
            | None => React.null
            }}
            {renderOptionalDetailRow(~label="Current period end", Billing.currentPeriodEnd(status))}
            {renderOptionalDetailRow(~label="Trial end", Billing.trialEnd(status))}
            {renderOptionalDetailRow(~label="Cancel date", Billing.cancelAt(status))}
            {renderOptionalDetailRow(~label="Canceled date", Billing.canceledAt(status))}
          </div>
          {switch Billing.canManage(status) {
          | true =>
            <div className="space-y-3 rounded-lg border bg-muted/30 p-3">
              <p className="text-xs text-muted-foreground">
                {React.string("Cancel, update payment method, and view invoices in Stripe.")}
              </p>
              {renderButton(
                ~request=CustomerPortal,
                ~label="Manage in Stripe",
                ~disabled,
                ~opening,
                ~variant=Button.Variant.Secondary,
              )}
            </div>
          | false => React.null
          }}
          {switch Billing.isAccessAllowed(status) {
          | true => React.null
          | false =>
            <div className="divide-y">
              {Billing.checkoutOptions
              ->Array.map(option =>
                <div
                  key={Billing.checkoutOptionTitle(option)}
                  className="grid gap-3 py-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 font-medium">
                      {React.string(Billing.checkoutOptionTitle(option))}
                      {switch Billing.checkoutOptionBadge(option) {
                      | Some(badge) =>
                        <Badge variant=Badge.Variant.Emerald> {React.string(badge)} </Badge>
                      | None => React.null
                      }}
                    </div>
                    <div className="text-base font-semibold">
                      {React.string(Billing.checkoutOptionPrice(option))}
                    </div>
                    <p className="text-xs text-muted-foreground">
                      {React.string(Billing.checkoutOptionDescription(option))}
                    </p>
                  </div>
                  {renderButton(
                    ~request=Billing.checkoutOptionRequest(option),
                    ~label=`Choose ${Billing.checkoutOptionTitle(option)}`,
                    ~disabled,
                    ~opening,
                    ~variant=switch Billing.checkoutOptionRecommended(option) {
                    | true => Button.Variant.Default
                    | false => Button.Variant.Secondary
                    },
                  )}
                </div>
              )
              ->React.array}
            </div>
          }}
          <p className="text-xs text-muted-foreground">
            {React.string(
              "After completing Stripe, return here to see your updated billing status.",
            )}
          </p>
        </Card.Content>
      </Card>
    }}
  </div>
}
