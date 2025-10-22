open WebAudioAPI

include AudioScheduledSourceNode.Impl({type t = constantSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConstantSourceNode)
*/
@new
external make: (
  ~context: baseAudioContext,
  ~options: constantSourceOptions=?,
) => constantSourceNode = "ConstantSourceNode"
