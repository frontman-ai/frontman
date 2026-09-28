open Vitest

describe("Client__ChangesView", () => {
  test("explains each unavailable diff reason", t => {
    t
    ->expect(Client__ChangesView.unavailableReasonLabel(Client__FileChanges.Binary))
    ->Expect.toBe("Text diff unavailable for binary files")
    t
    ->expect(Client__ChangesView.unavailableReasonLabel(Client__FileChanges.SizeLimited))
    ->Expect.toBe("Text diff unavailable because the file is too large")
    t
    ->expect(Client__ChangesView.unavailableReasonLabel(Client__FileChanges.Discontinuous))
    ->Expect.toBe("Text diff unavailable because recorded edits do not form a continuous history")
  })
})
