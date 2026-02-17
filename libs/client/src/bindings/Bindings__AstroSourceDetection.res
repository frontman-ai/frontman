// Astro Source Detection - uses annotation bindings from @frontman/bindings
// and resolves them to Client__Types.SourceLocation.t for the element selection pipeline

module Annotations = FrontmanBindings.AstroAnnotations

// Get source location for an element using Astro annotations.
// If the clicked element itself has no annotation, walks up the DOM tree
// to find the closest annotated ancestor (up to 20 levels). This handles
// clicks on child elements (text nodes, spans) inside annotated components.
let getElementSourceLocation = (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  switch Annotations.getAnnotationsApi(window) {
  | None => None
  | Some(api) => {
      let annotationOpt = api.get(element)->Nullable.toOption

      // Walk up to find closest annotated ancestor if direct lookup fails
      let finalAnnotation = switch annotationOpt {
      | Some(_) => annotationOpt
      | None => {
          let result = ref(None)
          let current = ref(element->WebAPI.Element.parentElement->Null.toOption)
          let depth = ref(0)
          while result.contents->Option.isNone && current.contents->Option.isSome && depth.contents < 20 {
            let el = current.contents->Option.getOrThrow
            let found = api.get(el)->Nullable.toOption
            switch found {
            | Some(_) => result := found
            | None => {
                current := el->WebAPI.Element.parentElement->Null.toOption
                depth := depth.contents + 1
              }
            }
          }
          result.contents
        }
      }

      finalAnnotation->Option.flatMap(annotation =>
        Annotations.parseLoc(annotation.loc)->Option.map(((line, column)) => {
          Client__Types.SourceLocation.componentName: Some(Annotations.extractFilename(annotation.file)),
          tagName: element.tagName->String.toLowerCase,
          file: annotation.file,
          line,
          column,
          parent: None,
          componentProps: None,
        })
      )
    }
  }
}
