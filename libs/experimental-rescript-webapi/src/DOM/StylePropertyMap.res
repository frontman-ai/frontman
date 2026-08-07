external asStylePropertyMapReadOnly: DomTypes.stylePropertyMap => DomTypes.stylePropertyMapReadOnly =
  "%identity"
@send
external getAll: (DomTypes.stylePropertyMap, string) => array<DomTypes.cssStyleValue> = "getAll"

@send
external has: (DomTypes.stylePropertyMap, string) => bool = "has"

@send
external set: (
  DomTypes.stylePropertyMap,
  ~property: string,
  ~values: DomTypes.cssStyleValue,
) => unit = "set"

@send
external set2: (DomTypes.stylePropertyMap, ~property: string, ~values: string) => unit = "set"

@send
external append: (
  DomTypes.stylePropertyMap,
  ~property: string,
  ~values: DomTypes.cssStyleValue,
) => unit = "append"

@send
external append2: (DomTypes.stylePropertyMap, ~property: string, ~values: string) => unit = "append"

@send
external delete: (DomTypes.stylePropertyMap, string) => unit = "delete"

@send
external clear: DomTypes.stylePropertyMap => unit = "clear"
