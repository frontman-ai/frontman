open WebAudioAPI

include AudioNode.Impl({type t = biquadFilterNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode)
*/
@new
external make: (~context: baseAudioContext, ~options: biquadFilterOptions=?) => biquadFilterNode =
  "BiquadFilterNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/BiquadFilterNode/getFrequencyResponse)
*/
@send
external getFrequencyResponse: (
  biquadFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
