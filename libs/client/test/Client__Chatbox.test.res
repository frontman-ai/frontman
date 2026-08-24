open Vitest

module Chatbox = Client__Chatbox
module Message = Client__State__Types.Message

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
