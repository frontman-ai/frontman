type t = WebWorkersTypes.sharedWorkerGlobalScope = private {
  ...WebWorkersTypes.sharedWorkerGlobalScope,
}

module Impl = (
  T: {
    type t
  },
) => {
  include Worker.Impl({type t = T.t})

  @send
  external close: T.t => unit = "close"
}

include Impl({type t = t})
