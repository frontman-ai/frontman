include AudioNode.Impl({type t = WebAudioTypes.dynamicsCompressorNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.dynamicsCompressorOptions=?,
) => WebAudioTypes.dynamicsCompressorNode = "DynamicsCompressorNode"
