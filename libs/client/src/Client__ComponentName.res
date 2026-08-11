let _reactComponentName: WebAPI.DOMAPI.element => Nullable.t<string> = %raw(`
  function(element) {
    try {
      var keys = Object.keys(element);
      for (var i = 0; i < keys.length; i++) {
        if (keys[i].startsWith("__reactFiber$") || keys[i].startsWith("__reactInternalInstance$")) {
          var fiber = element[keys[i]];
          var current = fiber;
          while (current) {
            if (current.type && typeof current.type === "function") {
              var name = current.type.displayName || current.type.name;
              if (name && name !== "Fragment" && name !== "Suspense" && !name.startsWith("_")) {
                return name;
              }
            }
            current = current.return;
          }
        }
      }
    } catch (e) {}
    return null;
  }
`)

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
  switch _reactComponentName(element)->Nullable.toOption {
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
