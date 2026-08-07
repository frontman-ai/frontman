include EventTarget.Impl({type t = ServiceWorkerTypes.serviceWorkerContainer})

@send
external register: (
  ServiceWorkerTypes.serviceWorkerContainer,
  string,
  ~options: ServiceWorkerTypes.registrationOptions=?,
) => promise<ServiceWorkerTypes.serviceWorkerRegistration> = "register"

@send
external getRegistration: (
  ServiceWorkerTypes.serviceWorkerContainer,
  ~clientURL: string=?,
) => Nullable.t<ServiceWorkerTypes.serviceWorkerRegistration> = "getRegistration"

@send
external getRegistrations: ServiceWorkerTypes.serviceWorkerContainer => promise<
  array<ServiceWorkerTypes.serviceWorkerRegistration>,
> = "getRegistrations"

@send
external startMessages: ServiceWorkerTypes.serviceWorkerContainer => unit = "startMessages"
