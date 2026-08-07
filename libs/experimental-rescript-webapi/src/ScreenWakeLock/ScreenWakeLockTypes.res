@@warning("-30")

type wakeLockType = | @as("screen") Screen

@editor.completeFrom(WakeLock)
type wakeLock = private {}

@editor.completeFrom(WakeLockSentinel)
type wakeLockSentinel = private {
  ...EventTypes.eventTarget,
  released: bool,
  @as("type")
  type_: wakeLockType,
}
