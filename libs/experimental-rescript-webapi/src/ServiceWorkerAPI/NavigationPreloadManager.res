open ServiceWorkerAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/enable)
*/
@send
external enable: navigationPreloadManager => promise<unit> = "enable"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/disable)
*/
@send
external disable: navigationPreloadManager => promise<unit> = "disable"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/setHeaderValue)
*/
@send
external setHeaderValue: (navigationPreloadManager, string) => promise<unit> = "setHeaderValue"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationPreloadManager/getState)
*/
@send
external getState: navigationPreloadManager => promise<navigationPreloadState> = "getState"
