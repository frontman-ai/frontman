@schema
type streamEvent = Agent__Bindings__Vercel.textStreamPart

@schema
type events =
  | TaskEvent(Agent__Task.t, Agent__Task.Event.t)
  | StreamEvent(Agent__Task.t, streamEvent)

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
