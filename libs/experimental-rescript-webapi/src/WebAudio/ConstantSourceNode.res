include AudioScheduledSourceNode.Impl({type t = WebAudioTypes.constantSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ConstantSourceNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.constantSourceOptions=?,
) => WebAudioTypes.constantSourceNode = "ConstantSourceNode"
