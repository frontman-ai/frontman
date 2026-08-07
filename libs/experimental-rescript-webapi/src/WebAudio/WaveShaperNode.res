include AudioNode.Impl({type t = WebAudioTypes.waveShaperNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.waveShaperOptions=?,
) => WebAudioTypes.waveShaperNode = "WaveShaperNode"
