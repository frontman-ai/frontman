include AudioNode.Impl({type t = WebAudioTypes.audioWorkletNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~name: string,
  ~options: WebAudioTypes.audioWorkletNodeOptions=?,
) => WebAudioTypes.audioWorkletNode = "AudioWorkletNode"
