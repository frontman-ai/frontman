type subscriptionStatus =
  | @as("none") NoSubscription
  | @as("trialing") Trialing
  | @as("active") Active
  | @as("past_due") PastDue
  | @as("canceled") Canceled
  | @as("incomplete") Incomplete
  | @as("incomplete_expired") IncompleteExpired
  | @as("unpaid") Unpaid
  | UnknownSubscriptionStatus(string)

@@live
let subscriptionStatusSchema = S.union([
  S.literal(NoSubscription),
  S.literal(Trialing),
  S.literal(Active),
  S.literal(PastDue),
  S.literal(Canceled),
  S.literal(Incomplete),
  S.literal(IncompleteExpired),
  S.literal(Unpaid),
  S.string->S.transform(_ => {
    parser: status => UnknownSubscriptionStatus(status),
    serializer: status =>
      switch status {
      | NoSubscription => "none"
      | Trialing => "trialing"
      | Active => "active"
      | PastDue => "past_due"
      | Canceled => "canceled"
      | Incomplete => "incomplete"
      | IncompleteExpired => "incomplete_expired"
      | Unpaid => "unpaid"
      | UnknownSubscriptionStatus(status) => status
      },
  }),
])

@schema
type interval =
  | @as("monthly") Monthly
  | @as("yearly") Yearly

@schema
type status = {
  @s.matches(subscriptionStatusSchema)
  status: subscriptionStatus,
  @as("access_allowed")
  accessAllowed: bool,
  @as("has_billing_customer")
  hasBillingCustomer: bool,
  @as("trial_eligible")
  trialEligible?: bool,
  @as("trial_days")
  trialDays?: int,
  interval: @s.null option<interval>,
  @as("current_period_end")
  currentPeriodEnd: @s.null option<string>,
  @as("trial_end")
  trialEnd: @s.null option<string>,
  @as("cancel_at")
  cancelAt: @s.null option<string>,
  @as("canceled_at")
  canceledAt: @s.null option<string>,
}

type state =
  | NotLoaded
  | Loaded(status)
  | Error(string)

type request = Status | Checkout(interval) | CustomerPortal

type flow = Idle | Opening | AwaitingCheckout | Failed(string)

@schema
type checkoutRequest = {interval: interval}

@schema
type urlResponse = {url: string}

@schema
type errorResponse = {error: string, @as("request_id") requestId: option<string>}

let requestPath = request =>
  switch request {
  | Status => "/api/billing/status"
  | Checkout(_) => "/api/billing/checkout"
  | CustomerPortal => "/api/billing/customer-portal"
  }

type checkoutOption = {
  interval: interval,
  title: string,
  price: string,
  description: string,
  badge: option<string>,
}

let accessAllowed = billingStatus =>
  switch billingStatus {
  | Loaded({accessAllowed: true}) => true
  | NotLoaded | Error(_) | Loaded(_) => false
  }

let isAccessAllowed = (billingStatus: status) => billingStatus.accessAllowed

let canManage = (billingStatus: status) => billingStatus.hasBillingCustomer

let subscriptionStatus = (billingStatus: status) => billingStatus.status

let activationMessage = (billingStatus: status) =>
  switch billingStatus.status {
  | NoSubscription => "Turn your next idea into a website improvement. Choose a plan to continue."
  | Incomplete | IncompleteExpired => "Checkout wasn't completed. Your request is still here."
  | Unpaid | PastDue => "Update your payment method to restore access to Frontman."
  | Canceled => "Reactivate Frontman to keep your website improvements moving."
  | Trialing | Active | UnknownSubscriptionStatus(_) => "Check your plan to continue with Frontman."
  }

let subscriptionStatusLabel = status =>
  switch status {
  | NoSubscription => "No active plan"
  | Trialing => "Trialing"
  | Active => "Active"
  | PastDue => "Past due"
  | Canceled => "Canceled"
  | Incomplete => "Incomplete"
  | IncompleteExpired => "Incomplete expired"
  | Unpaid => "Unpaid"
  | UnknownSubscriptionStatus(status) => status
  }

let statusLabel = (billingStatus: status) => subscriptionStatusLabel(billingStatus.status)

let interval = (billingStatus: status) => billingStatus.interval

let intervalLabel = interval =>
  switch interval {
  | Monthly => "Monthly"
  | Yearly => "Yearly"
  }

let currentPeriodEnd = (billingStatus: status) => billingStatus.currentPeriodEnd
let trialEnd = (billingStatus: status) => billingStatus.trialEnd
let cancelAt = (billingStatus: status) => billingStatus.cancelAt
let canceledAt = (billingStatus: status) => billingStatus.canceledAt

let checkoutOptions = [
  {
    interval: Yearly,
    title: "Yearly",
    price: "EUR 12.50 / seat / month",
    description: "EUR 150 billed once per year. Saves EUR 30.",
    badge: Some("Best value"),
  },
  {
    interval: Monthly,
    title: "Monthly",
    price: "EUR 15 / seat / month",
    description: "EUR 15 billed monthly.",
    badge: None,
  },
]

let checkoutOptionTitle = (option: checkoutOption) => option.title
let checkoutOptionPrice = (option: checkoutOption) => option.price
let checkoutOptionDescription = (option: checkoutOption) => option.description
let checkoutOptionBadge = (option: checkoutOption) => option.badge
let checkoutOptionRequest = (option: checkoutOption) => Checkout(option.interval)
let checkoutOptionRecommended = (option: checkoutOption) =>
  switch option.interval {
  | Yearly => true
  | Monthly => false
  }

let offeredTrialDays = (status: status) =>
  switch (status.trialEligible, status.trialDays, status.accessAllowed) {
  | (Some(true), Some(days), false) if days > 0 => Some(days)
  | _ => None
  }

let priceLabel = interval =>
  switch interval {
  | Monthly => "€15 per seat / month"
  | Yearly => "€150 per seat / year"
  }

let needsPaymentRecovery = (status: status) =>
  switch (status.status, status.hasBillingCustomer) {
  | (PastDue | Unpaid, true) => true
  | _ => false
  }
