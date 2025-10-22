open WebAPI.WebWorkersAPI

external getSelf: () => sharedWorkerGlobalScope = "self"

let self = getSelf()

self -> SharedWorkerGlobalScope.close
