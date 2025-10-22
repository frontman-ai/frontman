open WebAudioAPI

include AudioNode.Impl({type t = analyserNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode)
*/
@new
external make: (~context: baseAudioContext, ~options: analyserOptions=?) => analyserNode =
  "AnalyserNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getFloatFrequencyData)
*/
@send
external getFloatFrequencyData: (analyserNode, array<float>) => unit = "getFloatFrequencyData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getByteFrequencyData)
*/
@send
external getByteFrequencyData: (analyserNode, array<int>) => unit = "getByteFrequencyData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getFloatTimeDomainData)
*/
@send
external getFloatTimeDomainData: (analyserNode, array<float>) => unit = "getFloatTimeDomainData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getByteTimeDomainData)
*/
@send
external getByteTimeDomainData: (analyserNode, array<int>) => unit = "getByteTimeDomainData"
