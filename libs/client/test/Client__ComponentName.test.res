open Vitest

// ── Test fixtures ─────────────────────────────────────────────────────

// Create a plain DOM element (no React/Vue/Astro internals)
let makePlainElement: string => WebAPI.DOMAPI.element = %raw(`
  function(tag) { return { tagName: tag, parentElement: null } }
`)

// Create a DOM element with a React fiber attached
let makeReactElement: (string, string) => WebAPI.DOMAPI.element = %raw(`
  function(tag, componentName) {
    var el = { tagName: tag, parentElement: null };
    el["__reactFiber$test123"] = {
      type: function FakeComponent() {},
      return: null
    };
    el["__reactFiber$test123"].type.displayName = componentName;
    return el;
  }
`)

// Create a DOM element with Vue's __vueParentComponent attached
let makeVueElement: (string, string) => WebAPI.DOMAPI.element = %raw(`
  function(tag, componentName) {
    var el = { tagName: tag, parentElement: null };
    el.__vueParentComponent = {
      type: { __name: componentName },
      props: null,
      parent: null
    };
    return el;
  }
`)

// ── Tests ──────────────────────────────────────────────────────────────

describe("Client__ComponentName.getForElement", () => {
  test("returns None for a plain DOM element", t => {
    let el = makePlainElement("div")
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(None)
  })

  test("returns React component name from fiber", t => {
    let el = makeReactElement("div", "ActionsTable")
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(Some("ActionsTable"))
  })

  test("returns Vue component name from __vueParentComponent", t => {
    let el = makeVueElement("div", "FilterPanel")
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(Some("FilterPanel"))
  })

  test("React takes priority over Vue when both are present", t => {
    let el: WebAPI.DOMAPI.element = %raw(`
      (function() {
        var el = { tagName: "div", parentElement: null };
        el["__reactFiber$test123"] = {
          type: function RC() {},
          return: null
        };
        el["__reactFiber$test123"].type.displayName = "ReactComponent";
        el.__vueParentComponent = {
          type: { __name: "VueComponent" },
          props: null,
          parent: null
        };
        return el;
      })()
    `)
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(Some("ReactComponent"))
  })

  test("skips Fragment and Suspense component names", t => {
    let el: WebAPI.DOMAPI.element = %raw(`
      (function() {
        var el = { tagName: "div", parentElement: null };
        el["__reactFiber$test123"] = {
          type: function Fragment() {},
          return: null
        };
        el["__reactFiber$test123"].type.displayName = "Fragment";
        return el;
      })()
    `)
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(None)
  })

  test("skips component names starting with underscore", t => {
    let el: WebAPI.DOMAPI.element = %raw(`
      (function() {
        var el = { tagName: "div", parentElement: null };
        var fn = function() {};
        // displayName takes priority over function.name in the fiber walker
        fn.displayName = "_InternalComponent";
        el["__reactFiber$test123"] = {
          type: fn,
          return: null
        };
        return el;
      })()
    `)
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(None)
  })

  test("walks up React fiber tree to find nearest function component", t => {
    let el: WebAPI.DOMAPI.element = %raw(`
      (function() {
        var el = { tagName: "span", parentElement: null };
        el["__reactFiber$test123"] = {
          type: "span",
          return: {
            type: function TableHeader() {},
            return: null
          }
        };
        el["__reactFiber$test123"].return.type.displayName = "TableHeader";
        return el;
      })()
    `)
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(Some("TableHeader"))
  })
})
