include AudioNode.Impl({type t = WebAudioTypes.mediaStreamAudioSourceNode})

@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.mediaStreamAudioSourceOptions,
) => WebAudioTypes.mediaStreamAudioSourceNode = "MediaStreamAudioSourceNode"
