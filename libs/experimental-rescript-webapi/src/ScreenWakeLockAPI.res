@@warning("-30")

open EventAPI

type wakeLockType = | @as("screen") Screen

/**
[See WakeLock on MDN](https://developer.mozilla.org/docs/Web/API/WakeLock)
*/
@editor.completeFrom(WakeLock)
type wakeLock = {}

/**
[See WakeLockSentinel on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel)
*/
@editor.completeFrom(WakeLockSentinel)
type wakeLockSentinel = {
  ...eventTarget,
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
