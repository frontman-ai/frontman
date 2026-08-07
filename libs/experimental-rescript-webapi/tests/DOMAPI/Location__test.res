let location = DomGlobal.document.location

// Access properties using `.`
let href = location.href

// Invoke methods using the `->TypeModule`
location->Location.reload

let a = 0

// testing out editor autocomplete
let fn = (l: DOM.location) => l->Location.reload
