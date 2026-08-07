include AudioNode.Impl({type t = WebAudioTypes.channelSplitterNode})

@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.channelSplitterOptions=?,
) => WebAudioTypes.channelSplitterNode = "ChannelSplitterNode"
