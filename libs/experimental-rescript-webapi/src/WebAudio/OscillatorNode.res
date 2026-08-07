include AudioScheduledSourceNode.Impl({type t = WebAudioTypes.oscillatorNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.oscillatorOptions=?,
) => WebAudioTypes.oscillatorNode = "OscillatorNode"

@send
external setPeriodicWave: (WebAudioTypes.oscillatorNode, WebAudioTypes.periodicWave) => unit =
  "setPeriodicWave"
