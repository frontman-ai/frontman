include AudioScheduledSourceNode.Impl({type t = WebAudioTypes.constantSourceNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.constantSourceOptions=?,
) => WebAudioTypes.constantSourceNode = "ConstantSourceNode"
