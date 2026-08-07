external asHTMLCollection: DomTypes.htmlFormControlsCollection => DomTypes.htmlCollection<
  DomTypes.element,
> = "%identity"
@send
external item: (DomTypes.htmlFormControlsCollection, int) => DomTypes.element = "item"

@send
external namedItem: (DomTypes.htmlFormControlsCollection, string) => DomTypes.element = "namedItem"
