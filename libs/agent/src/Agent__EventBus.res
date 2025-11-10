@schema
type streamEvent = Agent__Bindings__Vercel.textStreamPart

@schema
type events =
  | TaskEvent(Agent__Task.id, Agent__Task.Event.t)
  | StreamEvent(Agent__Task.id, streamEvent)

let getTaskIdFromEvent = event => {
  switch event {
  | TaskEvent(id, _) => id
  | StreamEvent(id, _) => id
  }
}
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
