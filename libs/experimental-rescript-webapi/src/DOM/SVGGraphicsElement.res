include Element.Impl({type t = DomTypes.svgGraphicsElement})

external asSVGElement: DomTypes.svgGraphicsElement => DomTypes.svgElement = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGGraphicsElement/getBBox)
*/
@send
external getBBox: (
  DomTypes.svgGraphicsElement,
  ~options: DomTypes.svgBoundingBoxOptions=?,
) => DomTypes.domRect = "getBBox"

@send
external getCTM: DomTypes.svgGraphicsElement => DomTypes.domMatrix = "getCTM"

@send
external getScreenCTM: DomTypes.svgGraphicsElement => DomTypes.domMatrix = "getScreenCTM"
