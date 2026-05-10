// Opaque absolute/relative path classification for user/API path strings.
type t

// Parse a JSON/API path string into a typed absolute/relative path.
let fromString: string => t

// Explicit constructors for trusted call sites that already know the path kind.
let absolute: string => t
let relative: string => t

let toString: t => string

let fold: (t, ~absolute: string => 'a, ~relative: string => 'a) => 'a
