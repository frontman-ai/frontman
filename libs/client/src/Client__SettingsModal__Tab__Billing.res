module Alert = Client__UI__Alert
module Badge = Client__UI__Badge
module Button = Client__UI__Button
module Card = Client__UI__Card
module HostNavigation = Client__HostNavigation
module Spinner = Client__UI__Spinner
module Billing = Client__Billing
module State = Client__State

type stripeFlowStage =
  | StripeFlowInactive
  | StripeFlowOpen
  | StripeFlowClosed
  | StripeFlowBlocked({url: string})

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

let stripeFlowIsOpen = stripeFlowStage =>
  switch stripeFlowStage {
  | StripeFlowOpen => true
  | StripeFlowInactive | StripeFlowClosed | StripeFlowBlocked(_) => false
  }

let formatDate = value => {
  let date = Date.fromString(value)
  Intl.DateTimeFormat.make()->Intl.DateTimeFormat.format(date)
}

let buildBillingUrl = (~apiBaseUrl, ~path) => apiBaseUrl->Option.map(baseUrl => `${baseUrl}${path}`)

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

let renderCancellationNotice = billingStatus =>
  switch Billing.cancelAt(billingStatus) {
  | Some(cancelAt) =>
    <Alert className="border-amber-500/30 bg-amber-500/10 text-amber-950 dark:text-amber-100">
      <Alert.Title> {React.string("Subscription scheduled to cancel")} </Alert.Title>
      <Alert.Description className="text-amber-900/80 dark:text-amber-100/80">
        {React.string(`Access remains active until ${formatDate(cancelAt)}.`)}
      </Alert.Description>
    </Alert>
  | None => React.null
  }

let renderStripeFlowCopy = stripeFlowStage =>
  switch stripeFlowStage {
  | StripeFlowOpen =>
    <>
      <p className="text-sm text-muted-foreground">
        {React.string(
          "Complete any required steps in Stripe. Billing updates here automatically when Stripe sends confirmation.",
        )}
      </p>
    </>
  | StripeFlowClosed =>
    <>
      <p className="text-sm text-muted-foreground">
        {React.string(
          "Billing updates here automatically when Stripe sends confirmation. You can reopen Stripe if needed.",
        )}
      </p>
    </>
  | StripeFlowBlocked(_) =>
    <>
      <p className="text-sm text-muted-foreground">
        {React.string(
          "Popup blocked. Allow popups, then open Stripe again. Billing updates here automatically after Stripe confirms changes.",
        )}
      </p>
    </>
  | StripeFlowInactive => React.null
  }

let renderStripeFlowNotice = (~stripeFlowStage, ~onRetry) => {
  switch stripeFlowStage {
  | StripeFlowInactive => React.null
  | StripeFlowOpen | StripeFlowClosed | StripeFlowBlocked(_) =>
    <Card size=Card.Size.Sm>
      <Card.Content className="space-y-3">
        <div className="space-y-1"> {renderStripeFlowCopy(stripeFlowStage)} </div>
        {switch stripeFlowStage {
        | StripeFlowBlocked({url}) =>
          <Button variant=Button.Variant.Default onClick={_ => onRetry(~url)}>
            {React.string("Open Stripe again")}
          </Button>
        | StripeFlowOpen | StripeFlowClosed | StripeFlowInactive => React.null
        }}
      </Card.Content>
    </Card>
  }
}

let renderCheckoutButton = (
  ~url,
  ~label,
  ~stripeFlowIsOpen,
  ~onOpenStripeFlow,
  ~variant=Button.Variant.Default,
) => {
  let disabled = stripeFlowIsOpen || url->Option.isNone
  <Button
    variant
    className="w-full sm:w-40"
    disabled
    onClick={_ =>
      switch url {
      | Some(url) => onOpenStripeFlow(~url)
      | None => ()
      }}
  >
    {React.string(
      switch stripeFlowIsOpen {
      | true => "Stripe tab open"
      | false => label
      },
    )}
  </Button>
}

let renderCustomerManagementActions = (~apiBaseUrl, ~stripeFlowIsOpen, ~onOpenStripeFlow) => {
  let url = buildBillingUrl(~apiBaseUrl, ~path=Billing.customerPortalPath)
  <div className="space-y-3 rounded-lg border bg-muted/30 p-3">
    <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
      <div className="space-y-1">
        <div className="text-sm font-medium"> {React.string("Manage billing")} </div>
        <p className="text-xs text-muted-foreground">
          {React.string("Cancel, update payment method, and view invoices in Stripe.")}
        </p>
      </div>
      <Button
        variant=Button.Variant.Secondary
        className="w-full sm:w-auto"
        disabled={stripeFlowIsOpen || url->Option.isNone}
        onClick={_ =>
          switch url {
          | Some(url) => onOpenStripeFlow(~url)
          | None => ()
          }}
      >
        {React.string(
          switch stripeFlowIsOpen {
          | true => "Stripe tab open"
          | false => "Manage in Stripe"
          },
        )}
      </Button>
    </div>
  </div>
}

let renderCheckoutOption = (
  ~apiBaseUrl,
  ~path,
  ~title,
  ~price,
  ~description,
  ~stripeFlowIsOpen,
  ~onOpenStripeFlow,
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
      ~url=buildBillingUrl(~apiBaseUrl, ~path),
      ~label=`Choose ${title}`,
      ~stripeFlowIsOpen,
      ~onOpenStripeFlow,
      ~variant,
    )}
  </div>

let renderCheckoutActions = (~apiBaseUrl, ~stripeFlowIsOpen, ~onOpenStripeFlow) =>
  <div className="divide-y">
    {Billing.checkoutOptions
    ->Array.map((option: Billing.checkoutOption) =>
      renderCheckoutOption(
        ~apiBaseUrl,
        ~path=Billing.checkoutOptionPath(option),
        ~title=Billing.checkoutOptionTitle(option),
        ~price=Billing.checkoutOptionPrice(option),
        ~description=Billing.checkoutOptionDescription(option),
        ~stripeFlowIsOpen,
        ~onOpenStripeFlow,
        ~variant=switch Billing.checkoutOptionRecommended(option) {
        | true => Button.Variant.Default
        | false => Button.Variant.Secondary
        },
        ~badge=?Billing.checkoutOptionBadge(option),
      )
    )
    ->React.array}
  </div>

let renderStatusCard = (
  ~apiBaseUrl,
  ~stripeFlowIsOpen,
  ~onOpenStripeFlow,
  billingStatus: Billing.status,
) =>
  <Card size=Card.Size.Sm>
    <Card.Header>
      <Card.Action>
        <Badge variant={statusVariant(Billing.subscriptionStatus(billingStatus))}>
          {React.string(Billing.statusLabel(billingStatus))}
        </Badge>
      </Card.Action>
      <Card.Title> {React.string("Plan status")} </Card.Title>
      <Card.Description>
        {React.string("Stripe manages payment methods, invoices, and cancellation.")}
      </Card.Description>
    </Card.Header>
    <Card.Content className="space-y-4">
      {renderCancellationNotice(billingStatus)}
      <div className="divide-y">
        {switch Billing.interval(billingStatus) {
        | Some(interval) =>
          renderDetailRow(~label="Interval", ~value=Billing.intervalLabel(interval))
        | None => React.null
        }}
        {renderOptionalDetailRow(
          ~label="Current period end",
          Billing.currentPeriodEnd(billingStatus),
        )}
        {renderOptionalDetailRow(~label="Trial end", Billing.trialEnd(billingStatus))}
        {renderOptionalDetailRow(~label="Cancel date", Billing.cancelAt(billingStatus))}
        {renderOptionalDetailRow(~label="Canceled date", Billing.canceledAt(billingStatus))}
      </div>
      {switch Billing.canManage(billingStatus) {
      | true => renderCustomerManagementActions(~apiBaseUrl, ~stripeFlowIsOpen, ~onOpenStripeFlow)
      | false => React.null
      }}
      {switch Billing.isAccessAllowed(billingStatus) {
      | true => React.null
      | false => renderCheckoutActions(~apiBaseUrl, ~stripeFlowIsOpen, ~onOpenStripeFlow)
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

let renderError = error =>
  <div role="alert">
    <Card size=Card.Size.Sm className="ring-destructive/30">
      <Card.Header>
        <Card.Title className="text-destructive">
          {React.string("Billing status unavailable")}
        </Card.Title>
        <Card.Description className="text-destructive/80"> {React.string(error)} </Card.Description>
      </Card.Header>
    </Card>
  </div>

@react.component
let make = () => {
  let billingStatus = State.useSelector(State.Selectors.billingStatus)
  let acpSession = State.useSelector(State.Selectors.acpSession)
  let (stripeFlowStage, setStripeFlowStage) = React.useState(() => StripeFlowInactive)
  let stripeTabRef: React.ref<option<HostNavigation.managedTab>> = React.useRef(None)

  let apiBaseUrl = switch acpSession {
  | Client__State__Types.AcpSessionActive({apiBaseUrl}) => Some(apiBaseUrl)
  | Client__State__Types.NoAcpSession => None
  }

  let markStripeTabClosed = () => {
    stripeTabRef.current = None
    setStripeFlowStage(_ => StripeFlowClosed)
  }

  let openStripeFlow = (~url) => {
    switch HostNavigation.openManagedTab(~url) {
    | Some(tab) =>
      stripeTabRef.current = Some(tab)
      setStripeFlowStage(_ => StripeFlowOpen)
    | None =>
      stripeTabRef.current = None
      setStripeFlowStage(_ => StripeFlowBlocked({url: url}))
    }
  }

  React.useEffect(() => {
    switch stripeFlowStage {
    | StripeFlowOpen =>
      let intervalId = WebAPI.Global.setInterval2(~handler=() => {
        switch stripeTabRef.current {
        | Some(tab) =>
          switch HostNavigation.tabClosed(tab) {
          | true => markStripeTabClosed()
          | false => ()
          }
        | None => ()
        }
      }, ~timeout=1000)

      Some(() => WebAPI.Global.clearInterval(intervalId))
    | StripeFlowInactive | StripeFlowClosed | StripeFlowBlocked(_) => None
    }
  }, [stripeFlowStage])

  let stripeFlowIsOpen = stripeFlowStage->stripeFlowIsOpen

  <div className="space-y-4">
    {renderStripeFlowNotice(~stripeFlowStage, ~onRetry=openStripeFlow)}
    {switch billingStatus {
    | Billing.NotLoaded | Billing.Loading => renderLoading()
    | Billing.Loaded(billingStatus) =>
      renderStatusCard(
        ~apiBaseUrl,
        ~stripeFlowIsOpen,
        ~onOpenStripeFlow=openStripeFlow,
        billingStatus,
      )
    | Billing.Error(error) => renderError(error)
    }}
  </div>
}
