@send
external openNullable: (
  WebAPI.Window.t,
  ~url: string=?,
  ~target: string=?,
) => Nullable.t<WebAPI.Window.t> = "open"

@set external setOpener: (WebAPI.Window.t, Nullable.t<WebAPI.Window.t>) => unit = "opener"
