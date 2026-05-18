S.enableJson()

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
  | NoSubscription
  | Incomplete
  | IncompleteExpired => "Finish billing setup to start using Frontman."
  | Canceled
  | Unpaid
  | PastDue => "Your Frontman access has ended. Start a subscription to continue."
  | Trialing | Active | UnknownSubscriptionStatus(_) => "Activate billing to start using Frontman."
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

let checkoutPath = interval =>
  switch interval {
  | Monthly => "/billing/checkout/monthly"
  | Yearly => "/billing/checkout/yearly"
  }

let customerPortalPath = "/billing/customer-portal"

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
let checkoutOptionPath = (option: checkoutOption) => checkoutPath(option.interval)
let checkoutOptionRecommended = (option: checkoutOption) =>
  switch option.interval {
  | Yearly => true
  | Monthly => false
  }
