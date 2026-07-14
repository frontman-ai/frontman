include AudioNode.Impl({type t = WebAudioTypes.analyserNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.analyserOptions=?,
) => WebAudioTypes.analyserNode = "AnalyserNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getFloatFrequencyData)
*/
@send
external getFloatFrequencyData: (WebAudioTypes.analyserNode, array<float>) => unit =
  "getFloatFrequencyData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getByteFrequencyData)
*/
@send
external getByteFrequencyData: (WebAudioTypes.analyserNode, array<int>) => unit =
  "getByteFrequencyData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getFloatTimeDomainData)
*/
@send
external getFloatTimeDomainData: (WebAudioTypes.analyserNode, array<float>) => unit =
  "getFloatTimeDomainData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AnalyserNode/getByteTimeDomainData)
*/
@send
external getByteTimeDomainData: (WebAudioTypes.analyserNode, array<int>) => unit =
  "getByteTimeDomainData"
