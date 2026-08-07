@editor.completeFrom(Cache)
type cache = private {}

@editor.completeFrom(CacheStorage)
type cacheStorage = private {}

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

@editor.completeFrom(WorkerGlobalScope)
type workerGlobalScope = private {
  ...EventTypes.eventTarget,
  caches: cacheStorage,
  crossOriginIsolated: bool,
}

type workerType =
  | @as("classic") Classic
  | @as("module") Module

type workerOptions = {
  @as("type") mutable type_?: workerType,
  mutable credentials?: FetchTypes.requestCredentials,
  mutable name?: string,
}

@editor.completeFrom(SharedWorkerGlobalScope)
type sharedWorkerGlobalScope = private {
  ...workerGlobalScope,
  name: option<string>,
}
