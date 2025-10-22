open WebAudioAPI

include AudioNode.Impl({type t = iirFilterNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IIRFilterNode)
*/
@new
external make: (~context: baseAudioContext, ~options: iirFilterOptions) => iirFilterNode =
  "IIRFilterNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IIRFilterNode/getFrequencyResponse)
*/
@send
external getFrequencyResponse: (
  iirFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
