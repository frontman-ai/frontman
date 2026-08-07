module Impl = (
  T: {
    type t
  },
) => {
  include AudioNode.Impl({type t = T.t})

  external asAudioScheduledSourceNode: T.t => WebAudioTypes.audioScheduledSourceNode = "%identity"

  @send
  external start: (T.t, ~when_: float=?) => unit = "start"

  @send
  external stop: (T.t, ~when_: float=?) => unit = "stop"
}

include Impl({type t = WebAudioTypes.audioScheduledSourceNode})
