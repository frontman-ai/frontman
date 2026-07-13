include EventTarget.Impl({type t = ScreenWakeLockTypes.wakeLockSentinel})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel/release)
*/
@send
external release: ScreenWakeLockTypes.wakeLockSentinel => promise<unit> = "release"
