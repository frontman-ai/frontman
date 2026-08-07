include AudioNode.Impl({type t = WebAudioTypes.gainNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.gainOptions=?,
) => WebAudioTypes.gainNode = "GainNode"
