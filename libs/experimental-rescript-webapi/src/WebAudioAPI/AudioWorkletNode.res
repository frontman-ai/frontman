open WebAudioAPI

include AudioNode.Impl({type t = audioWorkletNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioWorkletNode)
*/
@new
external make: (
  ~context: baseAudioContext,
  ~name: string,
  ~options: audioWorkletNodeOptions=?,
) => audioWorkletNode = "AudioWorkletNode"
