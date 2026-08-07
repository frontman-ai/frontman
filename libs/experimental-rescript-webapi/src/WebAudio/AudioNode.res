module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asAudioNode: T.t => WebAudioTypes.audioNode = "%identity"

  @send
  external connect: (
    T.t,
    ~destinationNode: WebAudioTypes.audioNode,
    ~output: int=?,
    ~input: int=?,
  ) => WebAudioTypes.audioNode = "connect"

  @send
  external connect2: (T.t, ~destinationParam: WebAudioTypes.audioParam, ~output: int=?) => unit =
    "connect"

  @send
  external disconnect: T.t => unit = "disconnect"

  @send
  external disconnect2: (T.t, int) => unit = "disconnect"

  @send
  external disconnect3: (T.t, WebAudioTypes.audioNode) => unit = "disconnect"

  @send
  external disconnect4: (T.t, ~destinationNode: WebAudioTypes.audioNode, ~output: int) => unit =
    "disconnect"

  @send
  external disconnect5: (
    T.t,
    ~destinationNode: WebAudioTypes.audioNode,
    ~output: int,
    ~input: int,
  ) => unit = "disconnect"

  @send
  external disconnect6: (T.t, WebAudioTypes.audioParam) => unit = "disconnect"

  @send
  external disconnect7: (T.t, ~destinationParam: WebAudioTypes.audioParam, ~output: int) => unit =
    "disconnect"
}
