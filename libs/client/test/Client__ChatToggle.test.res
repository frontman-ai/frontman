open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

describe("Client__ChatToggle", () => {
  test("renders the close control while chat is expanded", t => {
    let html = renderToStaticMarkup(<Client__ChatToggle chatOpen=true onToggle={() => ()} />)

    t->expect(html->String.includes(`aria-label="Close chat"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-expanded="true"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-controls="chat-panel"`))->Expect.toBe(true)
    t->expect(html->String.includes(`data-icon="panel-left-close"`))->Expect.toBe(true)
    t->expect(html->String.includes("group-hover/chat-toggle:hidden"))->Expect.toBe(false)
  })

  test("renders the logo and open affordance while chat is collapsed", t => {
    let html = renderToStaticMarkup(<Client__ChatToggle chatOpen=false onToggle={() => ()} />)

    t->expect(html->String.includes(`aria-label="Open chat"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-expanded="false"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-controls="chat-panel"`))->Expect.toBe(false)
    t->expect(html->String.includes(`data-icon="panel-left-open"`))->Expect.toBe(true)
    t->expect(html->String.includes("group-hover:hidden"))->Expect.toBe(true)
    t->expect(html->String.includes("group-focus-visible:block"))->Expect.toBe(true)
  })
})
