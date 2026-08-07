include AudioNode.Impl({type t = WebAudioTypes.channelMergerNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.channelMergerOptions=?,
) => WebAudioTypes.channelMergerNode = "ChannelMergerNode"
