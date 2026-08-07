include AudioNode.Impl({type t = WebAudioTypes.delayNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.delayOptions=?,
) => WebAudioTypes.delayNode = "DelayNode"
