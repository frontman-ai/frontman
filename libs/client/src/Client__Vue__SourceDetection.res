// Vue 3 Source Detection - uses Vue's internal __vueParentComponent on DOM elements
// to resolve clicked elements to .vue SFC source locations.
//
// Vue 3 attaches component instances to DOM elements via `__vueParentComponent`.
// The component instance provides:
//   - instance.type.__file — absolute path to the .vue SFC (set by @vitejs/plugin-vue in dev)
//   - instance.type.__name — component name (from <script setup> or explicit name option)
//   - instance.props — the component's resolved props
//   - instance.parent — parent component instance (for building parent chain)
//   - instance.type.__frontman_templateLine — injected by our vite-plugin-vue-source.mjs

module Log = FrontmanLogs.Logs.Make({
  let component = #Global
})

// ── Vue component types & accessor module ──────────────────────────────
// Wraps the opaque Vue internal types behind a module with accessor
// functions so callers read `.getName` instead of pattern-matching
// across optional fields and fallbacks.
//
// Note: Sury schemas are not applicable here — these types represent
// live Vue runtime objects accessed via Obj.magic, not JSON being parsed.
// The data comes from Vue's internal `__vueParentComponent` and is never
// serialized/deserialized through JSON.

type vueComponentType = {
  __file?: string,
  __name?: string,
  name?: string,
  __frontman_templateLine?: int,
}

type rec vueComponentInstance = {
  @as("type") componentType: vueComponentType,
  props: Nullable.t<Dict.t<JSON.t>>,
  parent: Nullable.t<vueComponentInstance>,
}

// Encapsulate name/file/line resolution with fallback logic.
module VueComponent = {
  // Resolve a component's display name.
  // Preference: __name (from <script setup>) > name (explicit) > filename
  let getName = (instance: vueComponentInstance): option<string> => {
    let ct = instance.componentType
    switch ct.__name {
    | Some(n) => Some(n)
    | None =>
      switch ct.name {
      | Some(n) => Some(n)
      | None =>
        ct.__file->Option.map(Client__SourcePath.extractFilename)
      }
    }
  }

  let getFile = (instance: vueComponentInstance): option<string> =>
    instance.componentType.__file

  // Returns the template start line, defaulting to 1 when the Vite
  // plugin hasn't injected __frontman_templateLine.
  let getTemplateLine = (instance: vueComponentInstance): int =>
    switch instance.componentType.__frontman_templateLine {
    | Some(l) => l
    | None => 1
    }
}

// ── Tiny raw externals for non-standard JS interop ─────────────────────
// These access Vue internals or JS built-ins that have no ReScript binding.

// Access Vue 3's non-standard __vueParentComponent property on DOM elements.
// Returns the component instance or null/undefined if not a Vue-managed element.
let getVueComponent: WebAPI.DOMAPI.element => Nullable.t<vueComponentInstance> = %raw(`
  function(el) { return el.__vueParentComponent }
`)

// Check if a JS value is an Array — used for runtime classification of
// Vue reactive proxy values typed as JSON.t.
@scope("Array") @val
external isArray: 'a => bool = "isArray"

// ── Pure ReScript helpers ──────────────────────────────────────────────

// Walk up the DOM from startElement to find the nearest Vue component instance.
let findVueInstance = (
  startElement: WebAPI.DOMAPI.element,
): option<(WebAPI.DOMAPI.element, vueComponentInstance)> => {
  let el = ref(Some(startElement))
  let depth = ref(0)
  let result = ref(None)

  while el.contents->Option.isSome && depth.contents < 50 && result.contents->Option.isNone {
    let current = el.contents->Option.getOrThrow
    switch getVueComponent(current)->Nullable.toOption {
    | Some(instance) => result := Some((current, instance))
    | None =>
      el := current->WebAPI.Element.parentElement->Null.toOption
      depth := depth.contents + 1
    }
  }

  result.contents
}

// Serialize Vue component props, filtering out non-serializable values.
// Vue reactive proxies can hold functions, symbols, refs etc. — we keep only
// JSON-safe primitives and shallow objects/arrays under a size threshold.
let serializeProps = (rawProps: Nullable.t<Dict.t<JSON.t>>): option<Dict.t<JSON.t>> => {
  switch rawProps->Nullable.toOption {
  | None => None
  | Some(props) =>
    let clean = Dict.make()
    let hasProps = ref(false)

    // Dict.keysToArray uses Object.keys() — own enumerable props only,
    // no hasOwnProperty check needed (unlike for..in).
    props->Dict.keysToArray->Array.forEach(key => {
      // Skip Vue internal props (prefixed with __)
      switch key->String.startsWith("__") {
      | true => ()
      | false =>
        switch props->Dict.get(key) {
        | None => () // undefined prop — skip
        | Some(value) =>
          switch Js.typeof(value) {
          | "string" | "number" | "boolean" =>
            clean->Dict.set(key, value)
            hasProps := true
          | "object" =>
            // typeof null === "object" in JS, so check for null first.
            // Nullable.toOption handles this: null → None, object → Some.
            switch (Obj.magic(value): Nullable.t<JSON.t>)->Nullable.toOption {
            | None =>
              // null value
              clean->Dict.set(key, value)
              hasProps := true
            | Some(_) =>
              let isArr = isArray(value)
              let fallback = switch isArr {
              | true => JSON.String("[Array]")
              | false => JSON.String("{...}")
              }
              // JSON.stringifyAny can throw on circular references (common
              // with Vue reactive proxies). This is expected — we log and
              // fall back to a placeholder rather than crashing the entire
              // source detection for one non-serializable prop.
              let serialized = try {
                switch JSON.stringifyAny(value) {
                | Some(s) =>
                  let maxLen = switch isArr {
                  | true => 1000
                  | false => 500
                  }
                  switch String.length(s) < maxLen {
                  | true => value
                  | false =>
                    switch isArr {
                    | true =>
                      let len = (Obj.magic(value): array<JSON.t>)->Array.length
                      JSON.String(`[Array(${Int.toString(len)})]`)
                    | false => JSON.String("{...}")
                    }
                  }
                | None => fallback
                }
              } catch {
              | _ =>
                Log.warning(`Vue prop serialization failed for key: ${key}`)
                fallback
              }
              clean->Dict.set(key, serialized)
              hasProps := true
            }
          // Skip functions, symbols, bigint, undefined, etc.
          | _ => ()
          }
        }
      }
    })

    switch hasProps.contents {
    | true => Some(clean)
    | false => None
    }
  }
}

// Build a SourceLocation from a Vue component instance
let makeSourceLocation = (
  instance: vueComponentInstance,
  element: WebAPI.DOMAPI.element,
  ~parent: option<Client__Types.SourceLocation.t>,
): option<Client__Types.SourceLocation.t> => {
  switch VueComponent.getFile(instance) {
  | None => None
  | Some(file) =>
    switch Client__SourcePath.isNodeModulesPath(file) {
    | true => None
    | false =>
      Some({
        Client__Types.SourceLocation.componentName: VueComponent.getName(instance),
        tagName: element.tagName->String.toLowerCase,
        file,
        line: VueComponent.getTemplateLine(instance),
        column: 1,
        parent,
        componentProps: serializeProps(instance.props),
      })
    }
  }
}

// Get source location for an element using Vue 3 component instances.
//
// Strategy:
// 1. Walk up DOM from the clicked element to find the nearest __vueParentComponent
// 2. If it's a node_modules component, keep walking parents to find a source-project one
// 3. Build a parent chain by walking instance.parent and detecting file transitions
let getElementSourceLocation = (
  ~element: WebAPI.DOMAPI.element,
): option<Client__Types.SourceLocation.t> => {
  switch findVueInstance(element) {
  | None => None
  | Some((foundEl, instance)) =>
    // Phase 1: Find the nearest non-node_modules component.
    // If the clicked component is from node_modules, walk up via instance.parent.
    let selectedInstance = ref(instance)
    let selectedEl = ref(foundEl)

    // Walk up parent instances if current is from node_modules
    switch VueComponent.getFile(instance) {
    | Some(file) if Client__SourcePath.isNodeModulesPath(file) => {
        let current = ref(instance.parent->Nullable.toOption)
        while current.contents->Option.isSome {
          let parentInst = current.contents->Option.getOrThrow
          switch VueComponent.getFile(parentInst) {
          | Some(parentFile) if !Client__SourcePath.isNodeModulesPath(parentFile) =>
            ignore(parentFile)
            selectedInstance := parentInst
            current := None
          | _ => current := parentInst.parent->Nullable.toOption
          }
        }
      }
    | _ => ()
    }

    // Phase 2: Build the parent chain from component boundary transitions.
    // Walk up instance.parent and collect each file-change boundary into an
    // array (bottom-up order: immediate parent first, most distant last).
    // Then reduce the array to build the linked-list chain.
    //
    // Convention (matching Astro): the outermost node in the chain is the
    // most distant ancestor (parent: None), and the innermost is the
    // immediate parent. E.g. for A → B → C (user clicks C):
    //   C.parent = A { parent: B { parent: None } }
    // The server's format_parent_chain renders this as a numbered list
    // from outermost (depth 1) to innermost (depth N).
    switch VueComponent.getFile(selectedInstance.contents) {
    | None => None
    | Some(selectedFile) =>
      let parentBoundaries: array<vueComponentInstance> = []
      let lastFile = ref(selectedFile)
      let currentParent = ref(selectedInstance.contents.parent->Nullable.toOption)
      let depth = ref(0)

      while currentParent.contents->Option.isSome && depth.contents < 20 {
        let parentInst = currentParent.contents->Option.getOrThrow
        switch VueComponent.getFile(parentInst) {
        | Some(parentFile)
          if parentFile != lastFile.contents &&
            !Client__SourcePath.isNodeModulesPath(parentFile) =>
          parentBoundaries->Array.push(parentInst)
          lastFile := parentFile
        | _ => ()
        }
        currentParent := parentInst.parent->Nullable.toOption
        depth := depth.contents + 1
      }

      // Build the chain: reduce processes left-to-right over bottom-up order.
      // Each entry wraps the previous chain, so the most-distant ancestor
      // (last in array) ends up as the outermost node with parent: None,
      // and the immediate parent (first in array) is the innermost wrapper.
      let parentChain = parentBoundaries->Array.reduce(None, (chain, parentInst) => {
        let parentFile = VueComponent.getFile(parentInst)->Option.getOrThrow
        Some({
          Client__Types.SourceLocation.componentName: VueComponent.getName(parentInst),
          tagName: "component",
          file: parentFile,
          line: VueComponent.getTemplateLine(parentInst),
          column: 1,
          parent: chain,
          componentProps: serializeProps(parentInst.props),
        })
      })

      makeSourceLocation(
        selectedInstance.contents,
        selectedEl.contents,
        ~parent=parentChain,
      )
    }
  }
}
