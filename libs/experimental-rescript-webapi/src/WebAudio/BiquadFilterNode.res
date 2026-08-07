include AudioNode.Impl({type t = WebAudioTypes.biquadFilterNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.biquadFilterOptions=?,
) => WebAudioTypes.biquadFilterNode = "BiquadFilterNode"

@send
external getFrequencyResponse: (
  WebAudioTypes.biquadFilterNode,
  ~frequencyHz: array<float>,
  ~magResponse: array<float>,
  ~phaseResponse: array<float>,
) => unit = "getFrequencyResponse"
