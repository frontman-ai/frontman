open Prelude

@send
external item: (domStringList, int) => string = "item"

@send
external contains: (domStringList, string) => bool = "contains"
