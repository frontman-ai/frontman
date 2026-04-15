// Astro Source Detection - uses annotation bindings from @frontman/bindings
// and resolves them to Client__Types.SourceLocation.t for the element selection pipeline
//
// When a user clicks an element, we walk up the DOM ancestry to find annotated
// elements. Astro's compiler adds `data-astro-source-file` to every regular HTML
// element in a .astro file with that file's path. Component calls (e.g. <Image />)
// are NOT annotated, but the HTML elements inside them are annotated with the
// called component's path.
//
// This means: when `data-astro-source-file` changes from one file to another as we
// walk up the DOM, we've crossed a component boundary. We use this to:
// 1. Skip node_modules components (find the nearest source-project ancestor)
// 2. Build a parent chain of component boundaries

module Annotations = FrontmanBindings.AstroAnnotations

// Make a SourceLocation from an annotation + element
let makeSourceLocation = (
  annotation: Annotations.annotation,
  element: WebAPI.DOMAPI.element,
  ~parent: option<Client__Types.SourceLocation.t>,
): option<Client__Types.SourceLocation.t> => {
  Client__SourcePath.parseLoc(annotation.loc)->Option.map(((line, column)) => {
    // Use displayName from props injection if available, otherwise extract from file path
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

// Get source location for an element using Astro annotations.
//
// Strategy:
// 1. Find the annotation for the clicked element (or nearest annotated ancestor)
// 2. If it points to node_modules, keep walking up to find a source-project component
// 3. Build a parent chain by detecting file-path transitions in ancestors
//
// The parent chain captures component boundaries - when the annotation file changes
// from one .astro file to another as we walk up the DOM, that's a component boundary.
// Example: Image.astro -> HomeCTA.astro -> Layout.astro
let getElementSourceLocation = (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  switch Annotations.getAnnotationsApi(window) {
  | None => None
  | Some(api) => {
      // Phase 1: Collect all annotated ancestors with their elements, bottom-up.
      // We start from the clicked element and walk up.
      let ancestors: array<(Annotations.annotation, WebAPI.DOMAPI.element)> = []

      // Check the clicked element itself first
      switch api.get(element)->Nullable.toOption {
      | Some(ann) => ancestors->Array.push((ann, element))
      | None => ()
      }

      // Walk up the DOM collecting annotated ancestors
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

      // Phase 2: Find the first non-node_modules annotation.
      // This is the "selected component" - the one the user actually cares about.
      let firstSourceIdx =
        ancestors->Array.findIndex(((ann, _)) => !Client__SourcePath.isNodeModulesPath(ann.file))

      switch firstSourceIdx {
      | -1 =>
        // All annotations point to node_modules (e.g., Starlight internals).
        // Fall back to the content file path injected by the rehype plugin,
        // or to the first annotation if no content file is available.
        switch api.contentFile->Nullable.toOption {
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
            // Phase 3: Build the parent chain from component boundary transitions.
            // Starting after the selected element, walk up ancestors and record
            // each time the file path changes - that marks a component boundary.
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
