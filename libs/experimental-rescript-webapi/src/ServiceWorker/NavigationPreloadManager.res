@send
external enable: ServiceWorkerTypes.navigationPreloadManager => promise<unit> = "enable"

@send
external disable: ServiceWorkerTypes.navigationPreloadManager => promise<unit> = "disable"

@send
external setHeaderValue: (ServiceWorkerTypes.navigationPreloadManager, string) => promise<unit> =
  "setHeaderValue"

@send
external getState: ServiceWorkerTypes.navigationPreloadManager => promise<
  ServiceWorkerTypes.navigationPreloadState,
> = "getState"
