include AudioNode.Impl({type t = WebAudioTypes.mediaElementAudioSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaElementAudioSourceNode)
*/
@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.mediaElementAudioSourceOptions,
) => WebAudioTypes.mediaElementAudioSourceNode = "MediaElementAudioSourceNode"
