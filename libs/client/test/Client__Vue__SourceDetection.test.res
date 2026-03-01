open Vitest

// Access the module under test. These helpers are pure functions that
// don't require a real DOM — we can test them with fixture data.
module Vue = Client__Vue__SourceDetection

// ── Test fixtures ─────────────────────────────────────────────────────

// Create a test DOM element with a given tagName.
// parentElement: null mimics a root element (real DOM always returns null or Element).
let makeTestElement: string => WebAPI.DOMAPI.element = %raw(`
  function(tag) { return { tagName: tag, parentElement: null } }
`)

// Create a test Vue component instance
let makeTestInstance: (
  ~file: string=?,
  ~name: string=?,
  ~scriptName: string=?,
  ~templateLine: int=?,
  ~props: Js.Nullable.t<Dict.t<JSON.t>>=?,
  ~parent: Js.Nullable.t<Vue.vueComponentInstance>=?,
  unit,
) => Vue.vueComponentInstance = %raw(`
  function(file, name, scriptName, templateLine, props, parent) {
    return {
      type: {
        __file: file,
        __name: scriptName,
        name: name,
        __frontman_templateLine: templateLine,
      },
      props: props !== undefined ? props : null,
      parent: parent !== undefined ? parent : null,
    }
  }
`)

// ── VueComponent.getName ──────────────────────────────────────────────

describe("VueComponent.getName", () => {
  test("prefers __name (script setup) over name", t => {
    let instance = makeTestInstance(
      ~file="/src/App.vue",
      ~scriptName="App",
      ~name="AppFallback",
      (),
    )
    t->expect(Vue.VueComponent.getName(instance))->Expect.toEqual(Some("App"))
  })

  test("falls back to name when __name is missing", t => {
    let instance = makeTestInstance(~file="/src/App.vue", ~name="AppComponent", ())
    t->expect(Vue.VueComponent.getName(instance))->Expect.toEqual(Some("AppComponent"))
  })

  test("falls back to filename when both names are missing", t => {
    let instance = makeTestInstance(~file="/src/components/Counter.vue", ())
    t
    ->expect(Vue.VueComponent.getName(instance))
    ->Expect.toEqual(Some("Counter.vue"))
  })
})

// ── serializeProps ─────────────────────────────────────────────────────

describe("serializeProps", () => {
  test("returns None for null input", t => {
    t->expect(Vue.serializeProps(Nullable.null))->Expect.toBeNone
  })

  test("serializes string, number, boolean props", t => {
    let props = Dict.fromArray([
      ("title", JSON.String("Hello")),
      ("count", JSON.Number(42.0)),
      ("active", JSON.Boolean(true)),
    ])
    let result = Vue.serializeProps(Nullable.make(props))
    t->expect(result->Option.isSome)->Expect.toBe(true)
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("title"))->Expect.toEqual(Some(JSON.String("Hello")))
    t->expect(clean->Dict.get("count"))->Expect.toEqual(Some(JSON.Number(42.0)))
    t->expect(clean->Dict.get("active"))->Expect.toEqual(Some(JSON.Boolean(true)))
  })

  test("serializes null prop values", t => {
    let props = Dict.fromArray([("value", JSON.Null)])
    let result = Vue.serializeProps(Nullable.make(props))
    t->expect(result->Option.isSome)->Expect.toBe(true)
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("value"))->Expect.toEqual(Some(JSON.Null))
  })

  test("skips Vue internal props (__ prefix)", t => {
    let props = Dict.fromArray([
      ("__v_isRef", JSON.Boolean(true)),
      ("__v_isReactive", JSON.Boolean(true)),
      ("title", JSON.String("visible")),
    ])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("title"))->Expect.toEqual(Some(JSON.String("visible")))
    t->expect(clean->Dict.get("__v_isRef"))->Expect.toBeNone
    t->expect(clean->Dict.get("__v_isReactive"))->Expect.toBeNone
  })

  test("serializes small arrays as-is", t => {
    let arr = JSON.Array([JSON.Number(1.0), JSON.Number(2.0)])
    let props = Dict.fromArray([("items", arr)])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("items"))->Expect.toEqual(Some(arr))
  })

  test("truncates large arrays to placeholder", t => {
    // Create an array whose JSON.stringify output exceeds 1000 chars
    let bigArr = Array.make(~length=200, JSON.String("long-padding-string-value"))
    let props = Dict.fromArray([("data", JSON.Array(bigArr))])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    let serialized = clean->Dict.get("data")->Option.getOrThrow
    // Should be a placeholder string like "[Array(200)]"
    t->expect(serialized)->Expect.toEqual(JSON.String("[Array(200)]"))
  })

  test("serializes small objects as-is", t => {
    let obj = JSON.Object(Dict.fromArray([("a", JSON.Number(1.0))]))
    let props = Dict.fromArray([("config", obj)])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("config"))->Expect.toEqual(Some(obj))
  })

  test("truncates large objects to placeholder", t => {
    // Create an object whose JSON.stringify output exceeds 500 chars
    let entries = Array.make(~length=50, ("k", JSON.String("a-long-padding-value-here")))
    // Give unique keys so they all appear in the stringified output
    let uniqueEntries =
      entries->Array.mapWithIndex((entry, i) => {
        let (_, v) = entry
        (`key_${Int.toString(i)}`, v)
      })
    let obj = JSON.Object(Dict.fromArray(uniqueEntries))
    let props = Dict.fromArray([("settings", obj)])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("settings"))->Expect.toEqual(Some(JSON.String("{...}")))
  })

  test("skips function values", t => {
    let fn: JSON.t = Obj.magic(() => ())
    let props = Dict.fromArray([("onClick", fn), ("label", JSON.String("click me"))])
    let result = Vue.serializeProps(Nullable.make(props))
    let clean = result->Option.getOrThrow
    t->expect(clean->Dict.get("label"))->Expect.toEqual(Some(JSON.String("click me")))
    t->expect(clean->Dict.get("onClick"))->Expect.toBeNone
  })

  test("returns None when all props are internal or non-serializable", t => {
    let fn: JSON.t = Obj.magic(() => ())
    let props = Dict.fromArray([("__internal", JSON.Boolean(true)), ("handler", fn)])
    let result = Vue.serializeProps(Nullable.make(props))
    t->expect(result)->Expect.toBeNone
  })
})

// ── makeSourceLocation ─────────────────────────────────────────────────

describe("makeSourceLocation", () => {
  test("returns None when __file is missing", t => {
    let instance = makeTestInstance()
    let el = makeTestElement("DIV")
    let result = Vue.makeSourceLocation(instance, el, ~parent=None)
    t->expect(result)->Expect.toBeNone
  })

  test("returns None when file is from node_modules", t => {
    let instance = makeTestInstance(~file="/node_modules/vue/Component.vue", ())
    let el = makeTestElement("DIV")
    let result = Vue.makeSourceLocation(instance, el, ~parent=None)
    t->expect(result)->Expect.toBeNone
  })

  test("builds source location for a valid component", t => {
    let instance = makeTestInstance(
      ~file="/src/App.vue",
      ~scriptName="App",
      ~templateLine=5,
      (),
    )
    let el = makeTestElement("DIV")
    let result = Vue.makeSourceLocation(instance, el, ~parent=None)
    t->expect(result->Option.isSome)->Expect.toBe(true)
    let loc = result->Option.getOrThrow
    t->expect(loc.file)->Expect.toBe("/src/App.vue")
    t->expect(loc.componentName)->Expect.toEqual(Some("App"))
    t->expect(loc.line)->Expect.toBe(5)
    t->expect(loc.column)->Expect.toBe(1)
    t->expect(loc.tagName)->Expect.toBe("div")
    t->expect(loc.parent)->Expect.toBeNone
  })

  test("defaults line to 1 when __frontman_templateLine is missing", t => {
    let instance = makeTestInstance(~file="/src/App.vue", ())
    let el = makeTestElement("SPAN")
    let loc = Vue.makeSourceLocation(instance, el, ~parent=None)->Option.getOrThrow
    t->expect(loc.line)->Expect.toBe(1)
  })

  test("passes parent through", t => {
    let parentLoc: Client__Types.SourceLocation.t = {
      componentName: Some("Layout"),
      tagName: "component",
      file: "/src/Layout.vue",
      line: 1,
      column: 1,
      parent: None,
      componentProps: None,
    }
    let instance = makeTestInstance(~file="/src/Page.vue", ~scriptName="Page", ())
    let el = makeTestElement("SECTION")
    let loc =
      Vue.makeSourceLocation(instance, el, ~parent=Some(parentLoc))->Option.getOrThrow
    t->expect(loc.parent->Option.isSome)->Expect.toBe(true)
    let parent = loc.parent->Option.getOrThrow
    t->expect(parent.file)->Expect.toBe("/src/Layout.vue")
  })
})

// ── getElementSourceLocation integration ───────────────────────────────

describe("getElementSourceLocation", () => {
  test("returns None for a plain DOM element without Vue instance", t => {
    let el = makeTestElement("DIV")
    let result = Vue.getElementSourceLocation(~element=el)
    t->expect(result)->Expect.toBeNone
  })
})
