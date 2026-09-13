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
    t
    ->expect(
      inspect(~depth=2, ~nodes=1, "#inspection-root").html->String.includes("truncated nodes=1"),
    )
    ->Expect.toBe(true)
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
