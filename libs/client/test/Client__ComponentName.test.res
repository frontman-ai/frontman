open Vitest

let makePlainElement: string => WebAPI.DOMAPI.element = %raw(`
  function(tag) { return { tagName: tag, parentElement: null } }
`)

let makeReactElement: (string, string) => WebAPI.DOMAPI.element = %raw(`
  function(tag, componentName) {
    var el = { tagName: tag, parentElement: null };
    el["__reactFiber$test123"] = {
      type: "div",
      _debugOwner: {name: componentName, owner: null},
      return: null
    };
    return el;
  }
`)

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
          type: "div",
          _debugOwner: {name: "ReactComponent", owner: null},
          return: null
        };
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

  test("skips Next.js framework component names", t => {
    let el = makeReactElement("div", "SegmentViewNode")
    let result = Client__ComponentName.getForElement(el)
    t->expect(result)->Expect.toEqual(None)
  })
})
