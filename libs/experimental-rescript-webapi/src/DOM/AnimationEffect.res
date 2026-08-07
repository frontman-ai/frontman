@send
external getTiming: DomTypes.animationEffect => DomTypes.effectTiming = "getTiming"

@send
external getComputedTiming: DomTypes.animationEffect => DomTypes.computedEffectTiming =
  "getComputedTiming"

@send
external updateTiming: (
  DomTypes.animationEffect,
  ~timing: DomTypes.optionalEffectTiming=?,
) => unit = "updateTiming"
