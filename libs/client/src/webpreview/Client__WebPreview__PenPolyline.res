module Annotation = Client__Annotation__Types

@react.component
let make = (~points: array<Annotation.point>, ~offsetX: float=0.0, ~offsetY: float=0.0) => {
  let pointsAttr =
    points
    ->Array.map(point =>
      `${(point.x -. offsetX)->Float.toString},${(point.y -. offsetY)->Float.toString}`
    )
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
