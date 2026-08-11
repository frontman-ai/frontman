/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WakeLock/request)
*/
@send
external request: (
  ScreenWakeLockTypes.wakeLock,
  ~type_: ScreenWakeLockTypes.wakeLockType=?,
) => promise<ScreenWakeLockTypes.wakeLockSentinel> = "request"
