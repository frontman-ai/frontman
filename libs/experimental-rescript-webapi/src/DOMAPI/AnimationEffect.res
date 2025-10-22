open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/getTiming)
*/
@send
external getTiming: animationEffect => effectTiming = "getTiming"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/getComputedTiming)
*/
@send
external getComputedTiming: animationEffect => computedEffectTiming = "getComputedTiming"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnimationEffect/updateTiming)
*/
@send
external updateTiming: (animationEffect, ~timing: optionalEffectTiming=?) => unit = "updateTiming"
