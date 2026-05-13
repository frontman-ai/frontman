module Annotation = Client__Annotation__Types

let boundingBox = (annotation: Annotation.t): Annotation.boundingBox =>
  switch annotation.penShape {
  | Some(shape) => shape.boundingBox
  | None => {
      let rect = WebAPI.Element.getBoundingClientRect(annotation.element)
      {Annotation.x: rect.left, y: rect.top, width: rect.width, height: rect.height}
    }
  }
