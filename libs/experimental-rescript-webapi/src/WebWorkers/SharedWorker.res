type t = WebWorkersTypes.sharedWorker
type workerType = WebWorkersTypes.workerType
type workerOptions = WebWorkersTypes.workerOptions = {...WebWorkersTypes.workerOptions}

include EventTarget.Impl({type t = t})

@new
external make: string => t = "SharedWorker"

@new
external makeWithName: (string, string) => t = "SharedWorker"

@new
external makeWithOptions: (string, workerOptions) => t = "SharedWorker"

@get
external port: t => MessagePort.t = "port"
