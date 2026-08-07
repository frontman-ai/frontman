@send
external item: (DomTypes.mediaList, int) => string = "item"

@send
external appendMedium: (DomTypes.mediaList, string) => unit = "appendMedium"

@send
external deleteMedium: (DomTypes.mediaList, string) => unit = "deleteMedium"
