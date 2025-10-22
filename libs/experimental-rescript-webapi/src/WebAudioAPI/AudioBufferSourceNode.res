open WebAudioAPI

include AudioScheduledSourceNode.Impl({type t = audioBufferSourceNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode)
*/
@new
external make: (
  ~context: baseAudioContext,
  ~options: audioBufferSourceOptions=?,
) => audioBufferSourceNode = "AudioBufferSourceNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioBufferSourceNode/start)
*/
@send
external startA: (
  audioBufferSourceNode,
  ~when_: float=?,
  ~offset: float=?,
  ~duration: float=?,
) => unit = "start"
