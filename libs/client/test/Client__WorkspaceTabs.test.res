open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = (~view=Client__WorkspacePanel.Preview, ~fileChangeCount=0, ~supportsChanges=true) =>
  renderToStaticMarkup(
    <Client__WorkspaceTabs view fileChangeCount supportsChanges onViewChange={_ => ()} />,
  )

describe("Client__WorkspaceTabs", () => {
  test("renders Preview and disables zero-count Changes for supported frameworks", t => {
    let html = render()

    t->expect(html->String.includes(">Preview<"))->Expect.toBe(true)
    t->expect(html->String.includes(">Changes<"))->Expect.toBe(true)
    t->expect(html->String.includes(">0<"))->Expect.toBe(true)
    t->expect(html->String.includes(`disabled=""`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-pressed="true"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-pressed="false"`))->Expect.toBe(true)
  })

  test("marks Changes active and includes the changed-file count", t => {
    let html = render(~view=Client__WorkspacePanel.Changes, ~fileChangeCount=4)

    t->expect(html->String.includes(">4<"))->Expect.toBe(true)
    t->expect(html->String.includes(`disabled=""`))->Expect.toBe(false)
    t->expect(html->String.includes(`aria-pressed="true"`))->Expect.toBe(true)
    t->expect(html->String.includes(`aria-pressed="false"`))->Expect.toBe(true)
  })

  test("omits Changes for unsupported frameworks", t => {
    let html = render(~supportsChanges=false)

    t->expect(html->String.includes(">Preview<"))->Expect.toBe(true)
    t->expect(html->String.includes(">Changes<"))->Expect.toBe(false)
  })

  test("does not notify when the active view is selected", t => {
    let selected = ref(None)

    Client__WorkspaceTabs.selectView(
      ~currentView=Client__WorkspacePanel.Changes,
      ~selectedView=Client__WorkspacePanel.Changes,
      ~onViewChange=view => selected.contents = Some(view),
    )

    t->expect(selected.contents)->Expect.toBe(None)
  })

  test("notifies when another view is selected", t => {
    let selected = ref(None)

    Client__WorkspaceTabs.selectView(
      ~currentView=Client__WorkspacePanel.Preview,
      ~selectedView=Client__WorkspacePanel.Changes,
      ~onViewChange=view => selected.contents = Some(view),
    )

    t->expect(selected.contents)->Expect.toBe(Some(Client__WorkspacePanel.Changes))
  })
})
