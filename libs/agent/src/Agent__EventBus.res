// Pure Pub/Sub Event Bus

// System events - don't affect task state, just notify clients
// Just alias to the Vercel bindings type - no need to redefine
type streamEvent = Agent__Bindings__Vercel.streamPart

type events =
  | TaskEvent(Agent__Task.t, Agent__Task.evt) // Domain events (existing)
  | StreamEvent(Agent__Task.t, streamEvent) // System events (NEW)

type subscriber = events => unit
type t = {subs: array<subscriber>}

let make = (): t => {
  subs: [],
}

let emit = (bus: t, event: events): unit => {
  bus.subs->Array.forEach(sub => sub(event))
}

let on = (bus: t, handler: subscriber): t => {
  {subs: Array.concat(bus.subs, [handler])}
}

let off = (bus: t, handler: subscriber): t => {
  {subs: bus.subs->Array.filter(h => h !== handler)}
}
