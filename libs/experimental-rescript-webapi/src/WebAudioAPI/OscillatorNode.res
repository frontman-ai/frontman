open WebAudioAPI

include AudioScheduledSourceNode.Impl({type t = oscillatorNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode)
*/
@new
external make: (~context: baseAudioContext, ~options: oscillatorOptions=?) => oscillatorNode =
  "OscillatorNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OscillatorNode/setPeriodicWave)
*/
@send
external setPeriodicWave: (oscillatorNode, periodicWave) => unit = "setPeriodicWave"
