open WebAudioAPI

include AudioNode.Impl({type t = mediaStreamAudioDestinationNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioDestinationNode)
*/
@new
external make: (
  ~context: audioContext,
  ~options: audioNodeOptions=?,
) => mediaStreamAudioDestinationNode = "MediaStreamAudioDestinationNode"
