open ScreenWakeLockAPI

include EventTarget.Impl({type t = wakeLockSentinel})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WakeLockSentinel/release)
*/
@send
external release: wakeLockSentinel => promise<unit> = "release"
