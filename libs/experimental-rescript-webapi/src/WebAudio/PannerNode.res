include AudioNode.Impl({type t = WebAudioTypes.pannerNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.pannerOptions=?,
) => WebAudioTypes.pannerNode = "PannerNode"
