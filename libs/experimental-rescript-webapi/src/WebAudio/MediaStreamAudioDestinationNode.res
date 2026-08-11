include AudioNode.Impl({type t = WebAudioTypes.mediaStreamAudioDestinationNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioDestinationNode)
*/
@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.audioNodeOptions=?,
) => WebAudioTypes.mediaStreamAudioDestinationNode = "MediaStreamAudioDestinationNode"
