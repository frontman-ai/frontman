open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = status =>
  renderToStaticMarkup(
    <Client__WordPressConnectionCard
      status onConnect={() => ()} onCheck={() => ()} onSetAccess={_ => ()} settingsUrl=None
    />,
  )

test("saved links show persistent state without a credential-creation action", t => {
  let html = render(WordPressLinked({enabled: true}))
  t->expect(html->String.includes("This site is linked"))->Expect.toBe(true)
  t->expect(html->String.includes("credentials are valid"))->Expect.toBe(true)
  t->expect(html->String.includes("MCP enabled"))->Expect.toBe(true)
  t->expect(html->String.includes("entire site"))->Expect.toBe(true)
  t->expect(html->String.includes("does not revoke Application Passwords"))->Expect.toBe(true)
  t->expect(html->String.includes("<button"))->Expect.toBe(false)
})

test("disabled access retains the saved link", t => {
  let html = render(WordPressLinked({enabled: false}))
  t->expect(html->String.includes("MCP disabled"))->Expect.toBe(true)
  t->expect(html->String.includes("saved connection is retained"))->Expect.toBe(true)
  t->expect(html->String.includes("<button"))->Expect.toBe(false)
})

test("unknown and failed checks never offer credential creation", t => {
  t->expect(render(WordPressNotChecked)->String.includes("Connection status is unavailable"))->Expect.toBe(true)
  t->expect(render(WordPressChecking)->String.includes("<button"))->Expect.toBe(false)
  let html = render(WordPressConnectionFailed("Check failed"))
  t->expect(html->String.includes("Check again"))->Expect.toBe(true)
  t->expect(html->String.includes("Enable MCP and connect"))->Expect.toBe(false)
})

test("only an unlinked site offers approval and warns about tools", t => {
  let html = render(WordPressUnlinked)
  t->expect(html->String.includes("Enable MCP and connect"))->Expect.toBe(true)
  t->expect(html->String.includes("change and delete site content"))->Expect.toBe(true)
  t->expect(render(WordPressLinking)->String.includes("disabled"))->Expect.toBe(true)
})

test("opens native plugin settings in a protected tab", t => {
  let url = "https://example.test/wp-admin/options-general.php?page=frontman-diagnostics"
  let html = renderToStaticMarkup(
    <Client__WordPressConnectionCard status={WordPressLinked({enabled: true})} onConnect={() => ()} onCheck={() => ()} onSetAccess={_ => ()} settingsUrl={Some(url)} />,
  )
  t->expect(html->String.includes(`href="${url}"`))->Expect.toBe(true)
  t->expect(html->String.includes(`target="_blank"`))->Expect.toBe(true)
  t->expect(html->String.includes(`rel="noopener noreferrer"`))->Expect.toBe(true)
})

test("access toggle reflects state and blocks duplicate updates", t => {
  t->expect(render(WordPressLinked({enabled: true}))->String.includes(`checked=""`))->Expect.toBe(true)
  t->expect(render(WordPressLinked({enabled: false}))->String.includes(`checked=""`))->Expect.toBe(false)
  t->expect(render(WordPressUpdatingAccess({enabled: true}))->String.includes("disabled"))->Expect.toBe(true)
})

test("cleanup warning remains visible independently of connection status", t => {
  let html = renderToStaticMarkup(
    <Client__WordPressConnectionCard status={WordPressChecking} credentialWarning=true onConnect={() => ()} onCheck={() => ()} onSetAccess={_ => ()} settingsUrl=None />,
  )
  t->expect(html->String.includes("may have created"))->Expect.toBe(true)
  t->expect(html->String.includes("WordPress profile"))->Expect.toBe(true)
})
