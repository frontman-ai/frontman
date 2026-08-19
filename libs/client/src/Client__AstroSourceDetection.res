module Annotations = FrontmanBindings.AstroAnnotations

let makeSourceLocation = (
  annotation: Annotations.annotation,
  element: WebAPI.DomTypes.element,
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

let rec findAnnotation = (
  element: WebAPI.DomTypes.element,
  api: Annotations.annotationsApi,
  remaining: int,
  projectOnly: bool,
): option<(Annotations.annotation, WebAPI.DomTypes.element)> => {
  let annotation = switch api.get(element)->Nullable.toOption {
  | Some(annotation) =>
    switch (projectOnly, Client__SourcePath.isNodeModulesPath(annotation.file)) {
    | (false, false) | (false, true) | (true, false) => Some((annotation, element))
    | (true, true) => None
    }
  | None => None
  }

  switch annotation {
  | Some(annotation) => Some(annotation)
  | None =>
    switch element->WebAPI.Element.parentElement->Null.toOption {
    | Some(parent) =>
      switch remaining > 0 {
      | true => findAnnotation(parent, api, remaining - 1, projectOnly)
      | false => None
      }
    | None => None
    }
  }
}

let getElementSourceLocation = (
  ~element: WebAPI.DomTypes.element,
  ~window: WebAPI.DomTypes.window,
): option<Client__Types.SourceLocation.t> => {
  switch Annotations.getAnnotationsApi(window) {
  | None => None
  | Some(api) => {
      let nearestAnnotation = findAnnotation(element, api, 50, false)
      switch findAnnotation(element, api, 50, true) {
      | Some((annotation, annotatedElement)) =>
        makeSourceLocation(annotation, annotatedElement, ~parent=None)
      | None =>
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
          switch nearestAnnotation {
          | None => None
          | Some((annotation, annotatedElement)) =>
            makeSourceLocation(annotation, annotatedElement, ~parent=None)
          }
        }
      }
    }
  }
}
