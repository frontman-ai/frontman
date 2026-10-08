open Vitest

module Chatbox = Client__Chatbox
module Message = Client__State__Types.Message

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

describe("shouldRenderTurnError", () => {
  test("hides turn error when matching error message is already rendered", t => {
    let error = Message.ErrorMessage.make(
      ~id="agent-error-1",
      ~error="Authentication failed",
      ~category=#auth,
    )
    t
    ->expect(Chatbox.shouldRenderTurnError([Message.Error(error)], "agent-error-1"))
    ->Expect.toBe(false)
  })

  test("shows turn error when no matching error message exists", t => {
    let otherError = Message.ErrorMessage.make(
      ~id="older-error",
      ~error="Earlier failure",
      ~category=#auth,
    )

    t
    ->expect(Chatbox.shouldRenderTurnError([Message.Error(otherError)], "agent-error-1"))
    ->Expect.toBe(true)
  })
})

describe("ExecutePlanAction", () => {
  test("hides execute action without a selected model", t => {
    let html = renderToStaticMarkup(
      <Chatbox.ExecutePlanAction
        pendingPlanHandoff={Some()} selectedModelValue=None onExecute={() => ()}
      />,
    )

    t->expect(html->String.includes("Execute plan"))->Expect.toBe(false)
  })

  test("shows execute action when a plan and model are available", t => {
    let html = renderToStaticMarkup(
      <Chatbox.ExecutePlanAction
        pendingPlanHandoff={Some()} selectedModelValue={Some("test:model")} onExecute={() => ()}
      />,
    )

    t->expect(html->String.includes("Execute plan"))->Expect.toBe(true)
  })
})
