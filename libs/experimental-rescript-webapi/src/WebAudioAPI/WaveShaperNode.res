open WebAudioAPI

include AudioNode.Impl({type t = waveShaperNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WaveShaperNode)
*/
@new
external make: (~context: baseAudioContext, ~options: waveShaperOptions=?) => waveShaperNode =
  "WaveShaperNode"
