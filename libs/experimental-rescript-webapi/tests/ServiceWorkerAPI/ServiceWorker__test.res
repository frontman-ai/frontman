let self = ServiceWorkerScope.current

self->ServiceWorkerScope.addEventListener(EventTypes.Push, (event: PushEvent.t) => {
  Console.log("received push event")

  // Extract data
  let (title, body) = switch event.data {
  | Some(data) =>
    switch data->PushMessageData.json {
    | JSON.Object(dict{"title": JSON.String(title), "body": JSON.String(body)}) => (title, body)
    | _ => ("???", "???")
    }
  | None => ("???", "???")
  }

  // Handle some data sync
  event->PushEvent.waitUntil(self->ServiceWorkerScope.fetch("https://rescript-lang.org"))

  // Show notification
  self.registration
  ->ServiceWorkerRegistration.showNotification(
    ~title,
    ~options={
      body,
      icon: "/icon.png",
      actions: [{action: "open", title: "Open"}, {action: "close", title: "Close"}],
      // For example the id of a new data entry
      data: JSON.Number(17.),
      vibrate: [200, 50, 200, 50, 400],
    },
  )
  ->Promise.ignore
})

self->ServiceWorkerScope.addEventListener(EventTypes.NotificationClick, (
  event: Notification.notificationEvent,
) => {
  Console.log(`notification clicked: ${event.action}`)
  // Close the notification
  event.notification->Notification.close

  // Open a new window if that is relevant
  event.notification.data
  ->Option.flatMap(data => {
    switch data {
    | JSON.Number(id) => Some(Float.toString(id))
    | _ => None
    }
  })
  ->Option.forEach(id => {
    self.clients
    ->Clients.openWindow(`https://mywebsite.com/mydata/${id}`)
    ->Promise.ignore
  })
})
