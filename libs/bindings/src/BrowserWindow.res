type managedTab = WebAPI.DOMAPI.window

@send
external openNullable: (
  WebAPI.DOMAPI.window,
  ~url: string=?,
  ~target: string=?,
  ~features: string=?,
) => Nullable.t<managedTab> = "open"

@set external setOpener: (managedTab, Nullable.t<WebAPI.DOMAPI.window>) => unit = "opener"
@get external closed: managedTab => bool = "closed"
