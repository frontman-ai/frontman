let shared1: SharedWorker.t = SharedWorker.make("sharedworker.js")

let shared2: SharedWorker.t = SharedWorker.makeWithName("sharedworker.js", "name")

let shared3: SharedWorker.t = SharedWorker.makeWithOptions(
  "sharedworker.js",
  {
    name: "workerName",
    type_: WebWorkersTypes.Module,
  },
)

let port: MessagePort.t = SharedWorker.port(shared1)

let self = SharedWorkerScope.current

self->SharedWorkerScope.close
