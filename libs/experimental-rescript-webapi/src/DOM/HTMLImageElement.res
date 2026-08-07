include HTMLElement.Impl({type t = DomTypes.htmlImageElement})

@send
external decode: DomTypes.htmlImageElement => promise<unit> = "decode"
