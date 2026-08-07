module Annotations = FrontmanBindings.AstroAnnotations

let makeSourceLocation = (
  annotation: Annotations.annotation,
  element: WebAPI.DOMAPI.element,
  ~parent: option<Client__Types.SourceLocation.t>,
): option<Client__Types.SourceLocation.t> => {
  Client__SourcePath.parseLoc(annotation.loc)->Option.map(((line, column)) => {
    let name = switch annotation.displayName {
    | Some(n) => Some(n)
    | None => Some(Client__SourcePath.extractFilename(annotation.file))
    }

    {
      Client__Types.SourceLocation.componentName: name,
      tagName: element.tagName->String.toLowerCase,
      file: annotation.file,
      line,
      column,
      parent,
      componentProps: annotation.componentProps,
    }
  })
}

let getElementSourceLocation = (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  switch Annotations.getAnnotationsApi(window) {
  | None => None
  | Some(api) => {
      let ancestors: array<(Annotations.annotation, WebAPI.DOMAPI.element)> = []

      switch api.get(element)->Nullable.toOption {
      | Some(ann) => ancestors->Array.push((ann, element))
      | None => ()
      }

      let current = ref(element->WebAPI.Element.parentElement->Null.toOption)
      let depth = ref(0)
      let maxDepth = 50

      while current.contents->Option.isSome && depth.contents < maxDepth {
        let el = current.contents->Option.getOrThrow
        switch api.get(el)->Nullable.toOption {
        | Some(ann) => ancestors->Array.push((ann, el))
        | None => ()
        }
        current := el->WebAPI.Element.parentElement->Null.toOption
        depth := depth.contents + 1
      }

      let firstSourceIdx =
        ancestors->Array.findIndex(((ann, _)) => !Client__SourcePath.isNodeModulesPath(ann.file))

      switch firstSourceIdx {
      | -1 =>
        let contentFile = switch api.getContentFile {
        | Some(getContentFile) =>
          getContentFile(element)
          ->Nullable.toOption
          ->Option.orElse(api.contentFile->Nullable.toOption)
        | None => api.contentFile->Nullable.toOption
        }
        switch contentFile {
        | Some(contentFile) =>
          Some({
            Client__Types.SourceLocation.componentName: None,
            tagName: element.tagName->String.toLowerCase,
            file: contentFile,
            line: -1,
            column: -1,
            parent: None,
            componentProps: None,
          })
        | None =>
          switch ancestors->Array.get(0) {
          | None => None
          | Some((selectedAnn, selectedEl)) =>
            makeSourceLocation(selectedAnn, selectedEl, ~parent=None)
          }
        }
      | selectedIdx =>
        switch ancestors->Array.get(selectedIdx) {
        | None => None
        | Some((selectedAnn, selectedEl)) => {
            let (parentChain, _) =
              ancestors
              ->Array.slice(~start=selectedIdx + 1, ~end=Array.length(ancestors))
              ->Array.reduce((None, selectedAnn.file), ((parentChain, lastFile), (ann, el)) => {
                if ann.file != lastFile && !Client__SourcePath.isNodeModulesPath(ann.file) {
                  (makeSourceLocation(ann, el, ~parent=parentChain), ann.file)
                } else {
                  (parentChain, lastFile)
                }
              })

            makeSourceLocation(selectedAnn, selectedEl, ~parent=parentChain)
          }
        }
      }
    }
  }
}
