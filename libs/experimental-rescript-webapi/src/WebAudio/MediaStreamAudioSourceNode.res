include AudioNode.Impl({type t = WebAudioTypes.mediaStreamAudioSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaStreamAudioSourceNode)
*/
@new
external make: (
  ~context: WebAudioTypes.audioContext,
  ~options: WebAudioTypes.mediaStreamAudioSourceOptions,
) => WebAudioTypes.mediaStreamAudioSourceNode = "MediaStreamAudioSourceNode"
