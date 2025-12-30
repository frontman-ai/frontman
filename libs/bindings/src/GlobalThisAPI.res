// Bindings for JavaScript globalThis object

type t

// Get the global globalThis object
let globalThis: t = %raw(`globalThis`)

// Generic property accessors using dynamic field access
let get: (t, string) => option<'a> = %raw(`(obj, key) => obj[key]`)
let set: (t, string, 'a) => unit = %raw(`(obj, key, val) => { obj[key] = val }`)

// Typed property accessors
let getUnsafe: (t, string) => 'a = %raw(`(obj, key) => obj[key]`)
let getOpt: (t, string) => option<'a> = %raw(`(obj, key) => obj[key]`)
