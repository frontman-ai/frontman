@send
external request: (
  ScreenWakeLockTypes.wakeLock,
  ~type_: ScreenWakeLockTypes.wakeLockType=?,
) => promise<ScreenWakeLockTypes.wakeLockSentinel> = "request"
