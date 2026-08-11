/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/enable)
*/
@send
external enable: ServiceWorkerTypes.navigationPreloadManager => promise<unit> = "enable"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/disable)
*/
@send
external disable: ServiceWorkerTypes.navigationPreloadManager => promise<unit> = "disable"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/setHeaderValue)
*/
@send
external setHeaderValue: (ServiceWorkerTypes.navigationPreloadManager, string) => promise<unit> =
  "setHeaderValue"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/getState)
*/
@send
external getState: ServiceWorkerTypes.navigationPreloadManager => promise<
  ServiceWorkerTypes.navigationPreloadState,
> = "getState"
