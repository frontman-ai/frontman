open ServiceWorkerAPI

@send
external openWindow: (clients, string) => promise<windowClient> = "open"
