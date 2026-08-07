@send
external item: (DomTypes.cssStyleDeclaration, int) => string = "item"

@send
external getPropertyValue: (DomTypes.cssStyleDeclaration, string) => string = "getPropertyValue"

@send
external getPropertyPriority: (DomTypes.cssStyleDeclaration, string) => string =
  "getPropertyPriority"

@send
external setProperty: (
  DomTypes.cssStyleDeclaration,
  ~property: string,
  ~value: string,
  ~priority: string=?,
) => unit = "setProperty"

@send
external removeProperty: (DomTypes.cssStyleDeclaration, string) => string = "removeProperty"
