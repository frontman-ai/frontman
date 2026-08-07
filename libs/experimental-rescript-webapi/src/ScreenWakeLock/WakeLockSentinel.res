include EventTarget.Impl({type t = ScreenWakeLockTypes.wakeLockSentinel})

@send
external release: ScreenWakeLockTypes.wakeLockSentinel => promise<unit> = "release"
