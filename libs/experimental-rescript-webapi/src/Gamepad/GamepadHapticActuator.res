/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GamepadHapticActuator/playEffect)
*/
@send
external playEffect: (
  GamepadTypes.gamepadHapticActuator,
  ~type_: GamepadTypes.gamepadHapticEffectType,
  ~params: GamepadTypes.gamepadEffectParameters=?,
) => promise<GamepadTypes.gamepadHapticsResult> = "playEffect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GamepadHapticActuator/reset)
*/
@send
external reset: GamepadTypes.gamepadHapticActuator => promise<GamepadTypes.gamepadHapticsResult> =
  "reset"
