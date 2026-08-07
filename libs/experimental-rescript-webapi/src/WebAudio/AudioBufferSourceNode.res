include AudioScheduledSourceNode.Impl({type t = WebAudioTypes.audioBufferSourceNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.audioBufferSourceOptions=?,
) => WebAudioTypes.audioBufferSourceNode = "AudioBufferSourceNode"

@send
external startA: (
  WebAudioTypes.audioBufferSourceNode,
  ~when_: float=?,
  ~offset: float=?,
  ~duration: float=?,
) => unit = "start"
