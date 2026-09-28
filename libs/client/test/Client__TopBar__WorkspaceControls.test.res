open Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = (~view, ~fileChangeCount=3, ~isAgentRunning=false) =>
  renderToStaticMarkup(
    <Client__TopBar__WorkspaceControls
      view
      fileChangeCount
      isAgentRunning
      previewControls={<span> {React.string("Browser controls")} </span>}
    />,
  )

describe("Client__TopBar__WorkspaceControls", () => {
  test("shows browser controls only in Preview", t => {
    let html = render(~view=Client__WorkspacePanel.Preview)

    t->expect(html->String.includes("Browser controls"))->Expect.toBe(true)
    t->expect(html->String.includes("files changed"))->Expect.toBe(false)
  })

  test("shows the changes summary without browser controls in Changes", t => {
    let html = render(~view=Client__WorkspacePanel.Changes)

    t->expect(html->String.includes("Browser controls"))->Expect.toBe(false)
    t->expect(html->String.includes("3 files changed"))->Expect.toBe(true)
  })

  test("uses a singular changes summary", t => {
    let html = render(~view=Client__WorkspacePanel.Changes, ~fileChangeCount=1)

    t->expect(html->String.includes("1 file changed"))->Expect.toBe(true)
  })

  test("identifies completed-turn changes while the agent is running", t => {
    let html = render(~view=Client__WorkspacePanel.Changes, ~isAgentRunning=true)

    t->expect(html->String.includes("Updating: 3 files from completed turns"))->Expect.toBe(true)
    t->expect(html->String.includes("3 files changed"))->Expect.toBe(false)
  })

  test("uses a singular updating summary", t => {
    let html = render(
      ~view=Client__WorkspacePanel.Changes,
      ~fileChangeCount=1,
      ~isAgentRunning=true,
    )

    t->expect(html->String.includes("Updating: 1 file from completed turns"))->Expect.toBe(true)
  })

  test("keeps a full-height flexible region in both workspaces", t => {
    let previewHtml = render(~view=Client__WorkspacePanel.Preview)
    let changesHtml = render(~view=Client__WorkspacePanel.Changes)

    t->expect(previewHtml->String.includes("h-full flex-1"))->Expect.toBe(true)
    t->expect(changesHtml->String.includes("h-full flex-1"))->Expect.toBe(true)
  })
})
