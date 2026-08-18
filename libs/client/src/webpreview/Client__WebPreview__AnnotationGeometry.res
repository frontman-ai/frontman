module Annotation = Client__Annotation__Types

let scrollForElement = (element: WebAPI.DOMAPI.element): (float, float) =>
  element.ownerDocument
  ->Null.toOption
  ->Option.flatMap(doc => doc.defaultView->Null.toOption)
  ->Option.mapOr((0.0, 0.0), win => (win->WebAPI.Window.scrollX, win->WebAPI.Window.scrollY))

let boundingBox = (annotation: Annotation.t): Annotation.viewportBoundingBox =>
  switch annotation.penShape {
  | Some(shape) => {
      let (scrollX, scrollY) = annotation.element->scrollForElement
      shape.documentBoundingBox->Annotation.documentBoundingBoxToViewport(~scrollX, ~scrollY)
    }
  | None => {
      let rect = WebAPI.Element.getBoundingClientRect(annotation.element)
      Annotation.viewportBoundingBox(
        ~x=rect.left,
        ~y=rect.top,
        ~width=rect.width,
        ~height=rect.height,
      )
    }
  }
