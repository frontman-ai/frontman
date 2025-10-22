open ServiceWorkerAPI

include EventTarget.Impl({type t = serviceWorkerContainer})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/register)
*/
@send
external register: (
  serviceWorkerContainer,
  string,
  ~options: registrationOptions=?,
) => promise<serviceWorkerRegistration> = "register"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistration)
*/
@send
external getRegistration: (
  serviceWorkerContainer,
  ~clientURL: string=?,
) => Nullable.t<serviceWorkerRegistration> = "getRegistration"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistrations)
*/
@send
external getRegistrations: serviceWorkerContainer => promise<array<serviceWorkerRegistration>> =
  "getRegistrations"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/startMessages)
*/
@send
external startMessages: serviceWorkerContainer => unit = "startMessages"
