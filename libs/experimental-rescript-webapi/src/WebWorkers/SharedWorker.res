type t = WebWorkersTypes.sharedWorker
type workerType = WebWorkersTypes.workerType
type workerOptions = WebWorkersTypes.workerOptions = {...WebWorkersTypes.workerOptions}

include EventTarget.Impl({type t = t})

/**
`make(string)`

The SharedWorker() constructor creates a SharedWorker object that executes the 
script at the specified URL. This script must obey the same-origin policy.

```res
let shared: SharedWorker.t = SharedWorker.make("sharedworker.js")
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker/)
*/
@new
external make: string => t = "SharedWorker"

/**
`makeWithName(string, string)`

The SharedWorker() constructor creates a SharedWorker object that executes the 
script at the specified URL. This script must obey the same-origin policy.

```res
let shared: SharedWorker.t = SharedWorker.makeWithName("sharedworker.js", "name")
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker/)
*/
@new
external makeWithName: (string, string) => t = "SharedWorker"

/**
`makeWithOptions(string, workerOptions)`

The SharedWorker() constructor creates a SharedWorker object that executes the 
script at the specified URL. This script must obey the same-origin policy.

```res
let shared: SharedWorker.t = SharedWorker.makeWithOptions("sharedworker.js", {
  name: "workerName",
  type_: Module,
})
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker/)
*/
@new
external makeWithOptions: (string, workerOptions) => t = "SharedWorker"

/**
`port(sharedWorker)`

The port property of the SharedWorker interface returns a MessagePort object 
used to communicate and control the shared worker.

```res
let port: MessagePort.t = SharedWorker.port(myWorker)
```

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker/port)
*/
@get
external port: t => MessagePort.t = "port"
