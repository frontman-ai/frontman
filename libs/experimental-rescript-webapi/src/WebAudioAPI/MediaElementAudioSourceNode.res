open WebAudioAPI

include AudioNode.Impl({type t = mediaElementAudioSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaElementAudioSourceNode)
*/
@new
external make: (
  ~context: audioContext,
  ~options: mediaElementAudioSourceOptions,
) => mediaElementAudioSourceNode = "MediaElementAudioSourceNode"
