open WebAudioAPI

include AudioNode.Impl({type t = channelSplitterNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ChannelSplitterNode)
*/
@new
external make: (
  ~context: baseAudioContext,
  ~options: channelSplitterOptions=?,
) => channelSplitterNode = "ChannelSplitterNode"
