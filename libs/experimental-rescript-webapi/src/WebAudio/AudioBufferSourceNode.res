include AudioScheduledSourceNode.Impl({type t = WebAudioTypes.audioBufferSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.audioBufferSourceOptions=?,
) => WebAudioTypes.audioBufferSourceNode = "AudioBufferSourceNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/start)
*/
@send
external startA: (
  WebAudioTypes.audioBufferSourceNode,
  ~when_: float=?,
  ~offset: float=?,
  ~duration: float=?,
) => unit = "start"
