open WebWorkersAPI

module Impl = (
  T: {
    type t
  },
) => {
  include WorkerGlobalScope.Impl({type t = T.t})

  /**
`close(sharedWorkerGlobalScope)`

The close() method of the SharedWorkerGlobalScope interface discards any tasks 
queued in the SharedWorkerGlobalScope's event loop, effectively closing this 
particular scope.

```res
self -> SharedWorkerGlobalScope.close
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorkerGlobalScope/close)
*/
  @send
  external close: T.t => unit = "close"
}

include Impl({type t = sharedWorkerGlobalScope})
