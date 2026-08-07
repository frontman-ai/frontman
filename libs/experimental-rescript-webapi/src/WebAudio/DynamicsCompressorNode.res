include AudioNode.Impl({type t = WebAudioTypes.dynamicsCompressorNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.dynamicsCompressorOptions=?,
) => WebAudioTypes.dynamicsCompressorNode = "DynamicsCompressorNode"
