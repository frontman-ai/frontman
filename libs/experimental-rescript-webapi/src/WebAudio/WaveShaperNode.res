include AudioNode.Impl({type t = WebAudioTypes.waveShaperNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WaveShaperNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.waveShaperOptions=?,
) => WebAudioTypes.waveShaperNode = "WaveShaperNode"
