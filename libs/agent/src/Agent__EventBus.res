// Pure Pub/Sub Event Bus

type events = TaskEvent(Agent__Task.t, Agent__Task.evt)
// Future: ProjectEvent, UserEvent, etc.
type subscriber = events => unit
type t = {subs: ref<array<subscriber>>}

let make = (): t => {
  subs: ref([]),
}

let emit = (bus: t, event: events): unit => {
  bus.subs.contents->Array.forEach(sub => sub(event))
}

let on = (bus: t, handler: subscriber) => {
  bus.subs := Array.concat(bus.subs.contents, [handler])

  // Return unsubscribe function
  () => {
    bus.subs := bus.subs.contents->Array.filter(h => h !== handler)
  }
}
