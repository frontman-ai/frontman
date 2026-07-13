include AudioNode.Impl({type t = WebAudioTypes.channelMergerNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ChannelMergerNode)
*/
@new
external make: (
  ~context: WebAudioTypes.baseAudioContext,
  ~options: WebAudioTypes.channelMergerOptions=?,
) => WebAudioTypes.channelMergerNode = "ChannelMergerNode"
