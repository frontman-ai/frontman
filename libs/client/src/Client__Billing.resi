type status

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

type interval =
  | @as("monthly") Monthly
  | @as("yearly") Yearly

type state =
  | NotLoaded
  | Loaded(status)
  | Error(string)

type checkoutOption

let statusSchema: S.t<status>

let accessAllowed: state => bool
let isAccessAllowed: status => bool
let canManage: status => bool

let subscriptionStatus: status => subscriptionStatus
let activationMessage: status => string
let statusLabel: status => string

let interval: status => option<interval>
let intervalLabel: interval => string
let currentPeriodEnd: status => option<string>
let trialEnd: status => option<string>
let cancelAt: status => option<string>
let canceledAt: status => option<string>

let customerPortalPath: string
let checkoutOptions: array<checkoutOption>
let checkoutOptionTitle: checkoutOption => string
let checkoutOptionPrice: checkoutOption => string
let checkoutOptionDescription: checkoutOption => string
let checkoutOptionBadge: checkoutOption => option<string>
let checkoutOptionPath: checkoutOption => string
let checkoutOptionRecommended: checkoutOption => bool
