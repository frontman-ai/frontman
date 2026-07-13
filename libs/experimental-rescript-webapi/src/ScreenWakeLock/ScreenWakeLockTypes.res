@@warning("-30")

type wakeLockType = | @as("screen") Screen

/**
[See WakeLock on MDN](https://developer.mozilla.org/docs/Web/API/WakeLock)
*/
@editor.completeFrom(WakeLock)
type wakeLock = private {}

/**
[See WakeLockSentinel on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel)
*/
@editor.completeFrom(WakeLockSentinel)
type wakeLockSentinel = private {
  ...EventTypes.eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel/released)
    */
  released: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel/type)
    */
  @as("type")
  type_: wakeLockType,
}
