open Vitest
module Dom = Test__Dom
let inspect = (~depth=1, ~nodes=20, selector) =>
  Client__ElementInspector.inspect(
    ~element=Dom.query(selector),
    ~document=Dom.document,
    ~maxDepth=depth,
    ~maxNodes=nodes,
  )

describe("annotation element context", _ => {
  test(
    "includes caller-supplied attributes only when requested, using shared escaping and limits",
    t => {
      module Inspector = Client__ElementInspector
      let document = Dom.document
      Dom.html(`<main id="inspection-parent" data-boundary="outer"><div id="inspection-root" data-boundary="a&amp;&quot;b"><span data-boundary=""></span></div></main>`)
      let element = Dom.query("#inspection-root")
      let inspect = (~additionalAttributes=?) =>
        Inspector.inspect(~element, ~document, ~maxDepth=1, ~maxNodes=20, ~additionalAttributes?)
      t->expect(inspect().html->String.includes("data-boundary"))->Expect.toBe(false)
      let result = inspect(~additionalAttributes=["data-boundary"])
      ["data-boundary=\"outer\"", "data-boundary=\"a&\\\"b\"", "data-boundary=\"\""]->Array.forEach(
        field => t->expect(result.html->String.includes(field))->Expect.toBe(true),
      )
      let ancestor = Inspector.describeAncestor(
        ~element=Dom.query("#inspection-parent"),
        ~document,
        ~additionalAttributes=["data-boundary"],
      )
      t->expect(ancestor->String.includes("ancestor tag=\"main\""))->Expect.toBe(true)
      t
      ->expect(ancestor->String.includes("data-boundary=\"outer\" selector=\"#inspection-parent\""))
      ->Expect.toBe(true)
      element->WebAPI.Element.setAttribute(
        ~qualifiedName="data-boundary",
        ~value="é"->String.repeat(40_000),
      )
      let bounded = inspect(~additionalAttributes=["data-boundary"])
      t
      ->expect(bounded.html->String.includes(`data-boundary="${"é"->String.repeat(80)}..."`))
      ->Expect.toBe(true)
      t
      ->expect(WebAPI.Blob.make(~blobParts=[String(bounded.html)]).size <= 30_000)
      ->Expect.toBe(true)
    },
  )

  test("describes bounded context with navigable child selectors", t => {
    Dom.html(`<main id="parent"><div id="inspection-root">Root "text"<span>First</span><span>Second</span></div></main>`)
    let result = inspect("#inspection-root")
    t->expect(result.html->String.includes(`parent tag="main"`))->Expect.toBe(true)
    t
    ->expect(result.html->String.includes(`selected tag="div" id="inspection-root"`))
    ->Expect.toBe(true)
    t->expect(result.html->String.includes(`text="Root \\"text\\""`))->Expect.toBe(true)
    let selector = result.selector->Result.getOrThrow->Option.getOrThrow
    t->expect(Dom.query(selector))->Expect.toBe(Dom.query("#inspection-root"))
    let childSelector = `${selector} > :nth-child(1)`
    t
    ->expect(
      result.html->String.includes(
        `selector=${JSON.stringifyAny(childSelector)->Option.getOrThrow}`,
      ),
    )
    ->Expect.toBe(true)
    t
    ->expect((Dom.query(childSelector)->WebAPI.Element.asNode).textContent->Null.getOrThrow)
    ->Expect.toBe("First")
    t
    ->expect(inspect(~depth=0, "#inspection-root").html->String.includes("child tag"))
    ->Expect.toBe(false)
    let limited = inspect(~depth=2, ~nodes=1, "#inspection-root")
    t->expect(limited.nodeCount)->Expect.toBe(1)
    t->expect(limited.truncated)->Expect.toBe(true)
    t->expect(limited.html->String.includes("truncated nodes=1"))->Expect.toBe(true)
  })

  test("caps context at 30 KB of UTF-8", t => {
    let repeated = "é"->String.repeat(100)
    Dom.html(
      `<div id="inspection-root">${`<div class="${repeated}">${repeated}</div>`->String.repeat(
          199,
        )}</div>`,
    )
    let result = inspect(~nodes=200, "#inspection-root")
    t->expect(FrontmanBindings.WebStreams.utf8ByteSize(result.html) <= 30000)->Expect.toBe(true)
    t->expect(result.html->String.includes("truncated nodes="))->Expect.toBe(true)
    t->expect(result.truncated)->Expect.toBe(true)
  })

  test("returns navigable selectors through open shadow roots", t => {
    Dom.html(`<div id="shadow-host"></div>`)
    let host = Dom.query("#shadow-host")
    let shadow = host->WebAPI.Element.attachShadow({mode: Open})
    shadow.innerHTML = `<section><span></span><span id="nested-decoy"></span></section><button id="shadow-action">Save</button>`
    let result = Client__ElementInspector.inspect(
      ~element=host,
      ~document=Dom.document,
      ~maxDepth=2,
      ~maxNodes=20,
      ~pierceShadowDom=true,
      ~selectedSelector="#shadow-host",
    )
    t->expect(inspect("#shadow-host").html->String.includes("shadow-action"))->Expect.toBe(false)
    ["#shadow-host >>> 1/2", "#shadow-host >>> 2"]->Array.forEach(
      selector => {
        t
        ->expect(
          result.html->String.includes(
            `selector=${JSON.stringifyAny(selector)->Option.getOrThrow}`,
          ),
        )
        ->Expect.toBe(true)
        let (element, count) = Client__Tool__SelectorResolver.resolveBySelector(
          ~doc=Dom.document,
          ~selector,
        )
        t->expect(element->Option.isSome)->Expect.toBe(true)
        t->expect(count)->Expect.toBe(1)
      },
    )
  })

  test("omits control values and URL secrets", t => {
    Dom.html(`<form id="inspection-root">
      <input type="password" value="password-secret"><input type="hidden" value="hidden-token">
      <textarea>textarea-secret</textarea><a href="/account?token=url-secret#private">Account</a>
      <img src="/avatar?signature=image-secret" alt="Avatar">
      <a href="https://user:user-password@example.com/private">Private</a>
      <a href="//user:relative-password@example.com/private">Relative</a>
      <a href=" //user:spaced-password@example.com/private">Spaced</a>
      <img src="DATA:image/png;base64,image-data-secret" alt="Embedded"></form>`)
    let result = inspect(~nodes=200, "#inspection-root")
    [
      "password-secret",
      "hidden-token",
      "textarea-secret",
      "url-secret",
      "image-secret",
      "user-password",
      "relative-password",
      "spaced-password",
      "image-data-secret",
    ]->Array.forEach(secret => t->expect(result.html->String.includes(secret))->Expect.toBe(false))
    t->expect(result.nearbyText)->Expect.toEqual(None)
    t->expect(result.html->String.includes(`href="/account"`))->Expect.toBe(true)
    t->expect(result.html->String.includes(`src="/avatar"`))->Expect.toBe(true)
  })
})
