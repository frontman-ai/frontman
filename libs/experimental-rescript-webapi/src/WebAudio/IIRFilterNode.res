include AudioNode.Impl({type t = WebAudioTypes.iirFilterNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IIRFilterNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.iirFilterOptions,
) => WebAudioTypes.iirFilterNode = "IIRFilterNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/IIRFilterNode/getFrequencyResponse)
*/
@send
external getFrequencyResponse: (
  WebAudioTypes.iirFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
