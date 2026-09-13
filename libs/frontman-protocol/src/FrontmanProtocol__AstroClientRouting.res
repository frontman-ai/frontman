@schema
type t =
  | @as("enabled") Enabled
  | @as("disabled") Disabled
  | @as("unavailable") Unavailable
