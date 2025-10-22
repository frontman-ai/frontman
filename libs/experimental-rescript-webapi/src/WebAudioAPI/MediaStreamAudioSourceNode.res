open WebAudioAPI

include AudioNode.Impl({type t = mediaStreamAudioSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioSourceNode)
*/
@new
external make: (
  ~context: audioContext,
  ~options: mediaStreamAudioSourceOptions,
) => mediaStreamAudioSourceNode = "MediaStreamAudioSourceNode"
