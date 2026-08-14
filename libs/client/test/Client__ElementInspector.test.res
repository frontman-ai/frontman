open Vitest

@val external document: WebAPI.DOMAPI.document = "document"

let fixture = (): WebAPI.DOMAPI.element =>
  %raw(`
  (function() {
    window.CSS = window.CSS || {};
    window.CSS.escape = window.CSS.escape || function(value) { return value; };
    document.body.innerHTML = [
      '<main id="parent">',
      '  <section id="selected" class="card primary">',
      '    Selected text',
      '    <div id="overlay" class="absolute bg-gradient-to-t">',
      '      <span id="grandchild">Nested text</span>',
      '    </div>',
      '    <button id="action">Open</button>',
      '  </section>',
      '</main>'
    ].join('');
    var selected = document.querySelector('#selected');
    selected.getBoundingClientRect = function() {
      return {left: 10, top: 20, width: 300, height: 120};
    };
    return selected;
  })()
`)

describe("Client__ElementInspector.inspect", () => {
  test("returns selected metadata with one parent and direct children", t => {
    let inspected = Client__ElementInspector.inspect(
      ~element=fixture(),
      ~document,
      ~maxDepth=1,
      ~maxNodes=20,
      ~pierceShadowDom=false,
    )

    t->expect(inspected.tagName)->Expect.toBe("section")
    t->expect(inspected.selector)->Expect.toEqual(Ok(Some("#selected")))
    t->expect(inspected.cssClasses)->Expect.toEqual(Some("card primary"))
    t
    ->expect(inspected.nearbyText->Option.getOr("")->String.startsWith("Selected text"))
    ->Expect.toBe(true)
    t->expect(inspected.boundingBox.x)->Expect.toBe(10.0)
    t->expect(inspected.boundingBox.y)->Expect.toBe(20.0)
    t->expect(inspected.boundingBox.width)->Expect.toBe(300.0)
    t->expect(inspected.boundingBox.height)->Expect.toBe(120.0)
    t->expect(inspected.html->String.includes(`Parent: <main id="parent"`))->Expect.toBe(true)
    t
    ->expect(inspected.html->String.includes(`Selected:\n<section id="selected"`))
    ->Expect.toBe(true)
    t->expect(inspected.html->String.includes(`id="overlay"`))->Expect.toBe(true)
    t->expect(inspected.html->String.includes(`selector="#overlay"`))->Expect.toBe(true)
    t->expect(inspected.html->String.includes(`id="action"`))->Expect.toBe(true)
    t->expect(inspected.html->String.includes(`id="grandchild"`))->Expect.toBe(false)
  })

  test("includes deeper descendants and reports the node cap", t => {
    let inspected = Client__ElementInspector.inspect(
      ~element=fixture(),
      ~document,
      ~maxDepth=2,
      ~maxNodes=3,
      ~pierceShadowDom=false,
    )

    t->expect(inspected.html->String.includes(`id="grandchild"`))->Expect.toBe(true)
    t->expect(inspected.html->String.includes("context truncated at 3 nodes"))->Expect.toBe(true)
  })
})
