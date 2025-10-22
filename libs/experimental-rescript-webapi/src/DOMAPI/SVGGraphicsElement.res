open DOMAPI

include Element.Impl({type t = svgGraphicsElement})

external asSVGElement: svgGraphicsElement => svgElement = "%identity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SVGGraphicsElement/getBBox)
*/
@send
external getBBox: (svgGraphicsElement, ~options: svgBoundingBoxOptions=?) => domRect = "getBBox"

@send
external getCTM: svgGraphicsElement => domMatrix = "getCTM"

@send
external getScreenCTM: svgGraphicsElement => domMatrix = "getScreenCTM"
