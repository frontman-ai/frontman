open WebAudioAPI

include AudioNode.Impl({type t = convolverNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConvolverNode)
*/
@new
external make: (~context: baseAudioContext, ~options: convolverOptions=?) => convolverNode =
  "ConvolverNode"
