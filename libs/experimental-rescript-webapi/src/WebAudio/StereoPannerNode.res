include AudioNode.Impl({type t = WebAudioTypes.stereoPannerNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StereoPannerNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.stereoPannerOptions=?,
) => WebAudioTypes.stereoPannerNode = "StereoPannerNode"
