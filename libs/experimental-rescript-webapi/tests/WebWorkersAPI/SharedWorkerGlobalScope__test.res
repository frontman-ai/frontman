open WebAPI.WebWorkersAPI

external getSelf: unit => sharedWorkerGlobalScope = "self"

let self = getSelf()

self->SharedWorkerGlobalScope.close
