include AudioNode.Impl({type t = WebAudioTypes.biquadFilterNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.biquadFilterOptions=?,
) => WebAudioTypes.biquadFilterNode = "BiquadFilterNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/getFrequencyResponse)
*/
@send
external getFrequencyResponse: (
  WebAudioTypes.biquadFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
