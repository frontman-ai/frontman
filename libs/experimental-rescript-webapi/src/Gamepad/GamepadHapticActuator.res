@send
external playEffect: (
  GamepadTypes.gamepadHapticActuator,
  ~type_: GamepadTypes.gamepadHapticEffectType,
  ~params: GamepadTypes.gamepadEffectParameters=?,
) => promise<GamepadTypes.gamepadHapticsResult> = "playEffect"

@send
external reset: GamepadTypes.gamepadHapticActuator => promise<GamepadTypes.gamepadHapticsResult> =
  "reset"
