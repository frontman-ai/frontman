include DocumentFragment.Impl({type t = DomTypes.shadowRoot})

@send
external getAnimations: DomTypes.shadowRoot => array<DomTypes.animation> = "getAnimations"

@send
external setHTMLUnsafe: (DomTypes.shadowRoot, string) => unit = "setHTMLUnsafe"

@send
external getHTML: (DomTypes.shadowRoot, ~options: DomTypes.getHTMLOptions=?) => string = "getHTML"
