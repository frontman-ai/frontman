module Annotation = Client__Annotation__Types

@react.component
let make = (~points: array<Annotation.localPoint>) => {
  let pointsAttr =
    points
    ->Array.map(point => {
      let Annotation.LocalPoint(point) = point
      `${point.x->Float.toString},${point.y->Float.toString}`
    })
    ->Array.join(" ")

  <polyline
    points={pointsAttr}
    fill="none"
    stroke="white"
    strokeWidth="3"
    strokeLinecap="round"
    strokeLinejoin="round"
    vectorEffect="non-scaling-stroke"
    style={mixBlendMode: "difference"}
  />
}
