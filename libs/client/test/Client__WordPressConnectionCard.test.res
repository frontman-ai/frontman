open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = status =>
  renderToStaticMarkup(
    <Client__WordPressConnectionCard
      status onConnect={() => ()} onCheck={() => ()} onSetAccess={_ => ()} settingsUrl=None
    />,
  )

// Pending and unavailable states are transient during real network requests.
test("unknown and checking states never offer credential creation", t => {
  t->expect(render(WordPressNotChecked)->String.includes("Connection status is unavailable"))->Expect.toBe(true)
  t->expect(render(WordPressChecking)->String.includes("<button"))->Expect.toBe(false)
})

test("approval and access updates cannot be repeated while pending", t => {
  t->expect(render(WordPressLinking)->String.includes("disabled"))->Expect.toBe(true)
  t->expect(render(WordPressUpdatingAccess({enabled: true}))->String.includes("disabled"))->Expect.toBe(true)
})

test("cleanup warning remains visible independently of connection status", t => {
  let html = renderToStaticMarkup(
    <Client__WordPressConnectionCard status={WordPressChecking} credentialWarning=true onConnect={() => ()} onCheck={() => ()} onSetAccess={_ => ()} settingsUrl=None />,
  )
  t->expect(html->String.includes("may have created"))->Expect.toBe(true)
  t->expect(html->String.includes("WordPress profile"))->Expect.toBe(true)
})
