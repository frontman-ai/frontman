open Vitest

module Task = Client__Task__Types.Task
module UserContentPart = Client__Task__Types.UserContentPart

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let submission = (~id, ~text, ~status): Task.submission => {
  id,
  displayContent: [UserContentPart.text(text)],
  preparedContent: None,
  annotations: [],
  agentId: "executor-id",
  model: None,
  status,
}

describe("Client__QueuedMessagesDrawer", () => {
  test("renders queued count and latest submission preview", t => {
    let html = renderToStaticMarkup(
      <Client__QueuedMessagesDrawer
        submissions=[
          submission(~id="user-1", ~text="First prompt", ~status=Task.Preparing),
          submission(~id="user-2", ~text="Second prompt", ~status=Task.Accepted),
        ]
      />,
    )

    t->expect(html->String.includes("Queued (2)"))->Expect.toBe(true)
    t->expect(html->String.includes("Second prompt"))->Expect.toBe(true)
  })
})
