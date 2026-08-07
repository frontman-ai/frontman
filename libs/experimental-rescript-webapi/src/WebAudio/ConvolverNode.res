include AudioNode.Impl({type t = WebAudioTypes.convolverNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.convolverOptions=?,
) => WebAudioTypes.convolverNode = "ConvolverNode"
