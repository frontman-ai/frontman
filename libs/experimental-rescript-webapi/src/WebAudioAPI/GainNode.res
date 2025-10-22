open WebAudioAPI

include AudioNode.Impl({type t = gainNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/GainNode)
*/
@new
external make: (~context: baseAudioContext, ~options: gainOptions=?) => gainNode = "GainNode"
