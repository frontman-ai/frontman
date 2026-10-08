open Vitest
module Reducer = Client__State__StateReducer

test("draft serialization preserves whitespace while submission serialization trims it", t => {
  let content: Client__PromptEditor.jsonContentNode = {
    type_: "doc",
    content: [{type_: "paragraph", content: [{type_: "text", text: " Make signup "}]}],
  }
  t
  ->expect(Client__PromptEditor.serializePromptEditorContent(content, ~trim=false).text)
  ->Expect.toBe(" Make signup ")
  t
  ->expect(Client__PromptEditor.serializePromptEditorContent(content).text)
  ->Expect.toBe("Make signup")
})

test("drafts preserve whitespace through reconnect and checkout cancellation", t => {
  let drafted = Reducer.next(Reducer.defaultState, SetComposerDraft(" Make signup\n "))->Pair.first
  let reconnected = Reducer.next(drafted, ConnectionAction(Dispose))->Pair.first
  let canceled = Reducer.next(reconnected, BillingRequestCancelled({tab: None}))->Pair.first
  t->expect(canceled.composerDraft)->Expect.toBe(" Make signup\n ")
  t->expect(Reducer.Selectors.messages(canceled)->Array.length)->Expect.toBe(0)
})
