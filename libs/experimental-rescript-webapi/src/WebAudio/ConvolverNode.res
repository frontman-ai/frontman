include AudioNode.Impl({type t = WebAudioTypes.convolverNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConvolverNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.convolverOptions=?,
) => WebAudioTypes.convolverNode = "ConvolverNode"
