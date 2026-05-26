open Global

// Note that this only works when you added the `-open Global` bsc flag.
let location = window.location

// Access properties using `.`
location.href->ignore

// Invoke methods using the `->TypeModule`
location->Location.reload
