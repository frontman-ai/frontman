/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/getTiming)
*/
@send
external getTiming: DomTypes.animationEffect => DomTypes.effectTiming = "getTiming"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/getComputedTiming)
*/
@send
external getComputedTiming: DomTypes.animationEffect => DomTypes.computedEffectTiming =
  "getComputedTiming"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/updateTiming)
*/
@send
external updateTiming: (
  DomTypes.animationEffect,
  ~timing: DomTypes.optionalEffectTiming=?,
) => unit = "updateTiming"
