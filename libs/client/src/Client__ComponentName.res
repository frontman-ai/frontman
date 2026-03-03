// Synchronous component name detection across React, Vue, and Astro.
//
// Returns the display name of the nearest component owning a DOM element.
// Cheap enough to call per-node during DOM walks (microseconds, no I/O,
// no source maps). This is the sync counterpart to Client__SourceDetection
// which returns full SourceLocation.t asynchronously.
//
// Cascade order: React fiber → Vue instance → Astro annotation
// Each step is a pure in-memory property read with no network or parsing cost.

// ── React: walk __reactFiber$ to find nearest function component name ──

// Try to get React component name synchronously from fiber internals.
// Returns null if element is not React-rendered or fiber is inaccessible.
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

// ── Vue: read __vueParentComponent → getName ───────────────────────────

let _vueComponentName = (element: WebAPI.DOMAPI.element): option<string> => {
  switch Client__Vue__SourceDetection.getVueComponent(element)->Nullable.toOption {
  | Some(instance) => Client__Vue__SourceDetection.VueComponent.getName(instance)
  | None => None
  }
}

// ── Astro: read annotation displayName from window.__frontman_annotations__ ─

let _astroComponentName = (
  element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<string> => {
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

// ── Public API ─────────────────────────────────────────────────────────

// Resolve the component name for a DOM element, trying each framework
// in order: React → Vue → Astro. Returns None for plain HTML elements
// or unsupported frameworks.
//
// The ~window parameter is optional. Without it, only React and Vue
// detection run (Astro needs window.__frontman_annotations__). Callers
// that have a window reference (e.g. get_dom via withPreviewDoc) should
// pass it to get Astro coverage too.
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
