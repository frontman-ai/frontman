open GamepadAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GamepadHapticActuator/playEffect)
*/
@send
external playEffect: (
  gamepadHapticActuator,
  ~type_: gamepadHapticEffectType,
  ~params: gamepadEffectParameters=?,
) => promise<gamepadHapticsResult> = "playEffect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GamepadHapticActuator/reset)
*/
@send
external reset: gamepadHapticActuator => promise<gamepadHapticsResult> = "reset"
