module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external current: T.t = "self"

  @send
  external fetch: (T.t, string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"

  external fetchWithRequest: (T.t, Request.t, ~init: Request.requestInit=?) => promise<Response.t> =
    "fetch"
}

include Impl({type t = WebWorkersTypes.workerGlobalScope})
