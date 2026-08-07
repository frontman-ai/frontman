include AudioNode.Impl({type t = WebAudioTypes.analyserNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.analyserOptions=?,
) => WebAudioTypes.analyserNode = "AnalyserNode"

@send
external getFloatFrequencyData: (WebAudioTypes.analyserNode, array<float>) => unit =
  "getFloatFrequencyData"

@send
external getByteFrequencyData: (WebAudioTypes.analyserNode, array<int>) => unit =
  "getByteFrequencyData"

@send
external getFloatTimeDomainData: (WebAudioTypes.analyserNode, array<float>) => unit =
  "getFloatTimeDomainData"

@send
external getByteTimeDomainData: (WebAudioTypes.analyserNode, array<int>) => unit =
  "getByteTimeDomainData"
