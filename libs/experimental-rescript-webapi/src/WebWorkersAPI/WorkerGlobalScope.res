open WebWorkersAPI
open FetchAPI

module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  /**
`fetch(workerGlobalScope, string, init)`

The fetch() method of the WorkerGlobalScope interface starts the process of fetching a resource from the network, 
returning a promise that is fulfilled once the response is available.

```res
let response = await self->WorkerGlobalScope.fetch("https://rescript-lang.org")
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/fetch)
*/
  @send
  external fetch: (T.t, string, ~init: requestInit=?) => promise<response> = "fetch"

  /**
`fetchWithRequest(workerGlobalScope, request, init)`

The fetch() method of the WorkerGlobalScope interface starts the process of fetching a resource from the network, 
returning a promise that is fulfilled once the response is available.

```res
let response = await self->WorkerGlobalScope.fetch(myRequest)
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/fetch)
*/
  external fetchWithRequest: (T.t, request, ~init: requestInit=?) => promise<response> = "fetch"
}

include Impl({type t = workerGlobalScope})
