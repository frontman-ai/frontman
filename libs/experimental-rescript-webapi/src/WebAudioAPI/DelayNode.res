open WebAudioAPI

include AudioNode.Impl({type t = delayNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DelayNode)
*/
@new
external make: (~context: baseAudioContext, ~options: delayOptions=?) => delayNode = "DelayNode"
