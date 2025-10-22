open WebAudioAPI

include AudioNode.Impl({type t = stereoPannerNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StereoPannerNode)
*/
@new
external make: (~context: baseAudioContext, ~options: stereoPannerOptions=?) => stereoPannerNode =
  "StereoPannerNode"
