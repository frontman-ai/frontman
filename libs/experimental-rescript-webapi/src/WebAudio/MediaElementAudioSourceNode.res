include AudioNode.Impl({type t = WebAudioTypes.mediaElementAudioSourceNode})

@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.mediaElementAudioSourceOptions,
) => WebAudioTypes.mediaElementAudioSourceNode = "MediaElementAudioSourceNode"
