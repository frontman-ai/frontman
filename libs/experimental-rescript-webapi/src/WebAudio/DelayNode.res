include AudioNode.Impl({type t = WebAudioTypes.delayNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DelayNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.delayOptions=?,
) => WebAudioTypes.delayNode = "DelayNode"
