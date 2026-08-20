type t

@new
external make: unit => t = "FileReader"

@get
external result: t => Null.t<string> = "result"

@set
external setOnload: (t, EventTypes.event => unit) => unit = "onload"

@set
external setOnerror: (t, EventTypes.event => unit) => unit = "onerror"

@send
external readAsDataURL: (t, FileTypes.blob) => unit = "readAsDataURL"
