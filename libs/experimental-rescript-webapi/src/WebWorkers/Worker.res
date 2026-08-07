module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external current: T.t = "self"

  /**
`fetch(workerGlobalScope, string, init)`

The fetch() method of the WorkerGlobalScope interface starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await self->Worker.fetch("https://rescript-lang.org")
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/fetch)
*/
  @send
  external fetch: (T.t, string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"

  /**
`fetchWithRequest(workerGlobalScope, request, init)`

The fetch() method of the WorkerGlobalScope interface starts the process of fetching a resource from the network,
returning a promise that is fulfilled once the response is available.

```res
let response = await self->Worker.fetch(myRequest)
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/fetch)
*/
  external fetchWithRequest: (T.t, Request.t, ~init: Request.requestInit=?) => promise<Response.t> =
    "fetch"
}

include Impl({type t = WebWorkersTypes.workerGlobalScope})
