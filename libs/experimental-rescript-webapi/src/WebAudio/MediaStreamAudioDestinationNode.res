include AudioNode.Impl({type t = WebAudioTypes.mediaStreamAudioDestinationNode})

@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.audioNodeOptions=?,
) => WebAudioTypes.mediaStreamAudioDestinationNode = "MediaStreamAudioDestinationNode"
