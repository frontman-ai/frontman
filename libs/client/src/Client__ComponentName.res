@@live
type componentNameOptions = {
  excludedNames: array<string>,
  includeUnderscorePrefixed: bool,
  maxDepth: int,
}

@module("dom-element-to-component-source")
external reactComponentName: (WebAPI.DOMAPI.element, componentNameOptions) => Nullable.t<string> =
  "getElementComponentName"

let _reactComponentName = element =>
  reactComponentName(
    element,
    {
      excludedNames: ["SegmentViewNode", "LayoutRouterContext", "InnerLayoutRouter"],
      includeUnderscorePrefixed: false,
      maxDepth: 10,
    },
  )->Nullable.toOption

let _vueComponentName = (element: WebAPI.DOMAPI.element): option<string> => {
  switch Client__Vue__SourceDetection.getVueComponent(element)->Nullable.toOption {
  | Some(instance) => Client__Vue__SourceDetection.VueComponent.getName(instance)
  | None => None
  }
}

let _astroComponentName = (element: WebAPI.DOMAPI.element, ~window: WebAPI.DOMAPI.window): option<
  string,
> => {
  switch FrontmanBindings.AstroAnnotations.getAnnotationsApi(window) {
  | Some(api) =>
    switch api.get(element)->Nullable.toOption {
    | Some(annotation) =>
      switch annotation.displayName {
      | Some(name) => Some(name)
      | None => Some(Client__SourcePath.extractFilename(annotation.file))
      }
    | None => None
    }
  | None => None
  }
}

let getForElement = (
  element: WebAPI.DOMAPI.element,
  ~window: option<WebAPI.DOMAPI.window>=?,
): option<string> => {
  switch _reactComponentName(element) {
  | Some(name) => Some(name)
  | None =>
    switch _vueComponentName(element) {
    | Some(name) => Some(name)
    | None =>
      switch window {
      | Some(win) => _astroComponentName(element, ~window=win)
      | None => None
      }
    }
  }
}
