open WebAudioAPI

include AudioNode.Impl({type t = pannerNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PannerNode)
*/
@new
external make: (~context: baseAudioContext, ~options: pannerOptions=?) => pannerNode = "PannerNode"
