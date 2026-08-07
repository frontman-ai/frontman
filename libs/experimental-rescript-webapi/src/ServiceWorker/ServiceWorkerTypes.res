@@warning("-30")

type serviceWorkerState =
  | @as("activated") Activated
  | @as("activating") Activating
  | @as("installed") Installed
  | @as("installing") Installing
  | @as("parsed") Parsed
  | @as("redundant") Redundant

type serviceWorkerUpdateViaCache =
  | @as("all") All
  | @as("imports") Imports
  | @as("none") None

type workerType =
  | @as("classic") Classic
  | @as("module") Module

@editor.completeFrom(WebApiServiceWorker)
type serviceWorker = private {
  ...EventTypes.eventTarget,
  scriptURL: string,
  state: serviceWorkerState,
}

@editor.completeFrom(NavigationPreloadManager)
type navigationPreloadManager = private {}

@editor.completeFrom(ServiceWorkerRegistration)
type serviceWorkerRegistration = private {
  ...EventTypes.eventTarget,
  installing: Null.t<serviceWorker>,
  waiting: Null.t<serviceWorker>,
  active: Null.t<serviceWorker>,
  navigationPreload: navigationPreloadManager,
  scope: string,
  updateViaCache: serviceWorkerUpdateViaCache,
  pushManager: PushTypes.pushManager,
}

@editor.completeFrom(ServiceWorkerContainer)
type serviceWorkerContainer = private {
  ...EventTypes.eventTarget,
  controller: Null.t<serviceWorker>,
  ready: promise<serviceWorkerRegistration>,
}

type navigationPreloadState = {
  mutable enabled?: bool,
  mutable headerValue?: string,
}

type registrationOptions = {
  mutable scope?: string,
  @as("type") mutable type_?: WebWorkersTypes.workerType,
  mutable updateViaCache?: serviceWorkerUpdateViaCache,
}

type requestInfo = unknown

@editor.completeFrom(Clients)
type clients

@editor.completeFrom(ServiceWorkerGlobalScope)
type serviceWorkerGlobalScope = private {
  ...WebWorkersTypes.workerGlobalScope,
  clients: clients,
  registration: serviceWorkerRegistration,
}

type client = {
  id: string,
  url: string,
}

type windowClient = {
  ...client,
}
