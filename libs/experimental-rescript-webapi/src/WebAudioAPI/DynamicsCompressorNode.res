open WebAudioAPI

include AudioNode.Impl({type t = dynamicsCompressorNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DynamicsCompressorNode)
*/
@new
external make: (
  ~context: baseAudioContext,
  ~options: dynamicsCompressorOptions=?,
) => dynamicsCompressorNode = "DynamicsCompressorNode"
