type clientQueryOptions = {
  mutable includeUncontrolled?: bool,
  @as("type") mutable type_?: string,
}

@send
external get: (
  ServiceWorkerTypes.clients,
  string,
) => promise<Nullable.t<ServiceWorkerTypes.client>> = "get"

@send
external matchAll: (
  ServiceWorkerTypes.clients,
  ~options: clientQueryOptions=?,
) => promise<array<ServiceWorkerTypes.client>> = "matchAll"

@send
external openWindow: (
  ServiceWorkerTypes.clients,
  string,
) => promise<ServiceWorkerTypes.windowClient> = "openWindow"

@send
external claim: ServiceWorkerTypes.clients => promise<unit> = "claim"
