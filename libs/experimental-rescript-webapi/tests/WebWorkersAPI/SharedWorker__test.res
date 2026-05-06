open WebAPI.WebWorkersAPI

let shared1: sharedWorker = SharedWorker.make("sharedworker.js")

(SharedWorker.makeWithName("sharedworker.js", "name"): sharedWorker)->ignore

(
  SharedWorker.makeWithOptions(
    "sharedworker.js",
    {
      name: "workerName",
      type_: Module,
    },
  ): sharedWorker
)->ignore

(SharedWorker.port(shared1): WebAPI.ChannelMessagingAPI.messagePort)->ignore

external getSelf: unit => sharedWorkerGlobalScope = "self"

let self = getSelf()

self->SharedWorkerGlobalScope.close
