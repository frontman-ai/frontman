type readable
type writable

@module("process") @val
external stdin: readable = "stdin"

@module("process") @val
external stdout: writable = "stdout"

@send
external on: (readable, @string [#data(string => unit) | #error(JsError.t => unit)]) => unit = "on"
@send external write: (writable, string) => bool = "write"
@send external setEncoding: (readable, string) => unit = "setEncoding"

type chunk
external chunkToString: chunk => string = "toString"

type writeMethod<'a> = (chunk, array<'a>) => bool

@set external setWrite: (writable, writeMethod<'a>) => unit = "write"
