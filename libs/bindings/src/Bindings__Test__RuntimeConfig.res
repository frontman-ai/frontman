@get
external get: WebAPI.DomTypes.window => Nullable.t<JSON.t> = "__frontmanRuntime"

@set
external set: (WebAPI.DomTypes.window, Nullable.t<JSON.t>) => unit = "__frontmanRuntime"
