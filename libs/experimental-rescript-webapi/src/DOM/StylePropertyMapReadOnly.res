@send
external getAll: (DomTypes.stylePropertyMapReadOnly, string) => array<DomTypes.cssStyleValue> =
  "getAll"

@send
external has: (DomTypes.stylePropertyMapReadOnly, string) => bool = "has"
