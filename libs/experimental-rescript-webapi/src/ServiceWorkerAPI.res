@@warning("-30")

open Prelude
open EventAPI
open PushAPI
open WebWorkersAPI

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

/**
This ServiceWorker API interface provides a reference to a service worker. Multiple browsing contexts (e.g. pages, workers, etc.) can be associated with the same service worker, each through a unique ServiceWorker object.
[See ServiceWorker on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorker)
*/
@editor.completeFrom(ServiceWorker)
type serviceWorker = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorker/scriptURL)
    */
  scriptURL: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorker/state)
    */
  state: serviceWorkerState,
}

/**
[See NavigationPreloadManager on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager)
*/
@editor.completeFrom(NavigationPreloadManager)
type navigationPreloadManager = {}

/**
This ServiceWorker API interface represents the service worker registration. You register a service worker to control one or more pages that share the same origin.
[See ServiceWorkerRegistration on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration)
*/
@editor.completeFrom(ServiceWorkerRegistration)
type serviceWorkerRegistration = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/installing)
    */
  installing: Null.t<serviceWorker>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/waiting)
    */
  waiting: Null.t<serviceWorker>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/active)
    */
  active: Null.t<serviceWorker>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/navigationPreload)
    */
  navigationPreload: navigationPreloadManager,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/scope)
    */
  scope: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/updateViaCache)
    */
  updateViaCache: serviceWorkerUpdateViaCache,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/pushManager)
    */
  pushManager: pushManager,
}

/**
The ServiceWorkerContainer interface of the ServiceWorker API provides an object representing the service worker as an overall unit in the network ecosystem, including facilities to register, unregister and update service workers, and access the state of service workers and their registrations.
[See ServiceWorkerContainer on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer)
*/
@editor.completeFrom(ServiceWorkerContainer)
type serviceWorkerContainer = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/controller)
    */
  controller: Null.t<serviceWorker>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/ready)
    */
  ready: promise<serviceWorkerRegistration>,
}

type navigationPreloadState = {
  mutable enabled?: bool,
  mutable headerValue?: string,
}

type registrationOptions = {
  mutable scope?: string,
  @as("type") mutable type_?: workerType,
  mutable updateViaCache?: serviceWorkerUpdateViaCache,
}

type requestInfo = any

/**
The Clients interface provides access to Client objects. Access it via self.clients within a service worker.
[See Clients on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Clients)
 */
@editor.completeFrom(Clients)
type clients

/**
The ServiceWorkerGlobalScope interface of the Service Worker API represents the global execution context of a service worker.
[See ServiceWorkerGlobalScope on MDN](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope)
 */
@editor.completeFrom(ServiceWorkerGlobalScope)
type serviceWorkerGlobalScope = {
  ...workerGlobalScope,
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope/clients)
  */
  clients: clients,
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope/registration)
  */
  registration: serviceWorkerRegistration,
}

/**
The Client interface represents an executable context such as a Worker, or a SharedWorker. Window clients are represented by the more-specific WindowClient.
[See Client on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Client)
*/
type client = {
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Client/id)
  */
  id: string,
  /** [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Client/url) */
  url: string,
}

/**
The WindowClient interface of the ServiceWorker API represents the scope of a service worker client that is a document in a browsing context, controlled by an active worker.
[See WindowClient on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WindowClient)
*/
type windowClient = {
  ...client,
}
