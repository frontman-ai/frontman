include AudioNode.Impl({type t = WebAudioTypes.iirFilterNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.iirFilterOptions,
) => WebAudioTypes.iirFilterNode = "IIRFilterNode"

@send
external getFrequencyResponse: (
  WebAudioTypes.iirFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
