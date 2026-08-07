@get
external href: DomTypes.location => string = "href"

@send
external assign: (DomTypes.location, string) => unit = "assign"

@send
external replace: (DomTypes.location, string) => unit = "replace"

@send
external reload: DomTypes.location => unit = "reload"
