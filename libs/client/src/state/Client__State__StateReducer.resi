type state = Client__State__Protocol.state
type action = Client__State__Protocol.action
type effect = Client__State__Protocol.effect

let name: string
let next: (state, action) => (state, array<effect>)
