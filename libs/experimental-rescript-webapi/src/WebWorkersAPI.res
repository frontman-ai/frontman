open EventAPI
open FetchAPI

/**
Provides a storage mechanism for Request / Response object pairs that are cached, for example as part of the ServiceWorker life cycle. Note that the Cache interface is exposed to windowed scopes as well as workers. You don't have to use it in conjunction with service workers, even though it is defined in the service worker spec.
[See Cache on MDN](https://developer.mozilla.org/docs/Web/API/Cache)
*/
@editor.completeFrom(Cache)
type cache = {}

/**
The storage for Cache objects.
[See CacheStorage on MDN](https://developer.mozilla.org/docs/Web/API/CacheStorage)
*/
@editor.completeFrom(CacheStorage)
type cacheStorage = {}

type cacheQueryOptions = {
  mutable ignoreSearch?: bool,
  mutable ignoreMethod?: bool,
  mutable ignoreVary?: bool,
}

type multiCacheQueryOptions = {
  ...cacheQueryOptions,
  mutable cacheName?: string,
}

type sharedWorker

/**
The WorkerGlobalScope interface of the Web Workers API is an interface representing the scope of any worker.
Workers have no browsing context; this scope contains the information usually conveyed by Window objects —
in this case event handlers, the console or the associated WorkerNavigator object. 
Each WorkerGlobalScope has its own event loop.
[See WorkerGlobalScope on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope)
*/
@editor.completeFrom(WorkerGlobalScope)
type workerGlobalScope = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/caches)
    */
  caches: cacheStorage,
  /**
    [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/crossOriginIsolated)
    */
  crossOriginIsolated: bool,
}

type workerType =
  | @as("classic") Classic
  | @as("module") Module

/** An object containing option properties that can set when creating the
object instance. */
type workerOptions = {
  @as("type") mutable type_?: workerType,
  mutable credentials?: requestCredentials,
  mutable name?: string,
}

/**
The `SharedWorkerGlobalScope` object (the `SharedWorker` global scope) is 
accessible through the self keyword. Some additional global functions, 
namespaces objects, and constructors, not typically associated with the worker 
global scope, but available on it, are listed in the JavaScript Reference. See 
the complete list of functions available to workers.
*/
@editor.completeFrom(SharedWorkerGlobalScope)
type sharedWorkerGlobalScope = {
  ...workerGlobalScope,
  name: option<string>,
}
