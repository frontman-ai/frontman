open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = view =>
  renderToStaticMarkup(
    <Client__WorkspacePanel
      view
      preview={<span> {React.string("Preview workspace")} </span>}
      changes={<span> {React.string("Changes workspace")} </span>}
    />,
  )

describe("Client__WorkspacePanel", () => {
  test("falls back to Preview when Changes is unavailable", t => {
    t
    ->expect(
      Client__WorkspacePanel.availableView(
        ~view=Client__WorkspacePanel.Changes,
        ~fileChangeCount=0,
      ),
    )
    ->Expect.toBe(Client__WorkspacePanel.Preview)
  })

  test("keeps Changes selected when files are available", t => {
    t
    ->expect(
      Client__WorkspacePanel.availableView(
        ~view=Client__WorkspacePanel.Changes,
        ~fileChangeCount=1,
      ),
    )
    ->Expect.toBe(Client__WorkspacePanel.Changes)
  })

  test("renders Preview content", t => {
    let html = render(Client__WorkspacePanel.Preview)

    t->expect(html->String.includes("Preview workspace"))->Expect.toBe(true)
    t->expect(html->String.includes("Changes workspace"))->Expect.toBe(false)
  })

  test("renders Changes content", t => {
    let html = render(Client__WorkspacePanel.Changes)

    t->expect(html->String.includes("Preview workspace"))->Expect.toBe(false)
    t->expect(html->String.includes("Changes workspace"))->Expect.toBe(true)
  })
})
