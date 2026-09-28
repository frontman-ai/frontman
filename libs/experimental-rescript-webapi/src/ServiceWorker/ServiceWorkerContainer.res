include EventTarget.Impl({type t = ServiceWorkerTypes.serviceWorkerContainer})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/register)
*/
@send
external register: (
  ServiceWorkerTypes.serviceWorkerContainer,
  string,
  ~options: ServiceWorkerTypes.registrationOptions=?,
) => promise<ServiceWorkerTypes.serviceWorkerRegistration> = "register"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistration)
*/
@send
external getRegistration: (
  ServiceWorkerTypes.serviceWorkerContainer,
  ~clientURL: string=?,
) => Nullable.t<ServiceWorkerTypes.serviceWorkerRegistration> = "getRegistration"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistrations)
*/
@send
external getRegistrations: ServiceWorkerTypes.serviceWorkerContainer => promise<
  array<ServiceWorkerTypes.serviceWorkerRegistration>,
> = "getRegistrations"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/startMessages)
*/
@send
external startMessages: ServiceWorkerTypes.serviceWorkerContainer => unit = "startMessages"
