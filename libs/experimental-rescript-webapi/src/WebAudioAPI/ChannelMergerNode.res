open WebAudioAPI

include AudioNode.Impl({type t = channelMergerNode})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ChannelMergerNode)
*/
@new
external make: (~context: baseAudioContext, ~options: channelMergerOptions=?) => channelMergerNode =
  "ChannelMergerNode"
