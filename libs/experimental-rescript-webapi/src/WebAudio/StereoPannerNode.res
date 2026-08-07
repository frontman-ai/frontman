include AudioNode.Impl({type t = WebAudioTypes.stereoPannerNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.stereoPannerOptions=?,
) => WebAudioTypes.stereoPannerNode = "StereoPannerNode"
