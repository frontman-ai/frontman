@@warning("-30")
type gamepadMappingType =
  | @as("standard") Standard
  | @as("xr-standard") XrStandard

type gamepadHapticEffectType =
  | @as("dual-rumble") DualRumble
  | @as("trigger-rumble") TriggerRumble

type gamepadHapticsResult =
  | @as("complete") Complete
  | @as("preempted") Preempted

type gamepadButton = {
  pressed: bool,
  touched: bool,
  value: float,
}

@editor.completeFrom(GamepadHapticActuator)
type gamepadHapticActuator = private {}

type gamepad = {
  id: string,
  index: int,
  connected: bool,
  timestamp: float,
  mapping: gamepadMappingType,
  axes: array<float>,
  buttons: array<gamepadButton>,
  vibrationActuator: gamepadHapticActuator,
}

type gamepadEffectParameters = {
  mutable duration?: int,
  mutable startDelay?: int,
  mutable strongMagnitude?: float,
  mutable weakMagnitude?: float,
  mutable leftTrigger?: float,
  mutable rightTrigger?: float,
}
