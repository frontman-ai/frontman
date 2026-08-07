@send
external define: (
  DomTypes.customElementRegistry,
  ~name: string,
  ~constructor: DomTypes.htmlElement,
  ~options: DomTypes.elementDefinitionOptions=?,
) => unit = "define"

@send
external getName: (DomTypes.customElementRegistry, DomTypes.customElementConstructor) => string =
  "getName"

@send
external whenDefined: (
  DomTypes.customElementRegistry,
  string,
) => promise<DomTypes.customElementConstructor> = "whenDefined"

@send
external upgrade: (DomTypes.customElementRegistry, DomTypes.node) => unit = "upgrade"
