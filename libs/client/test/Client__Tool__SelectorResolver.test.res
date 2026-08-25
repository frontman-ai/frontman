open Vitest

test("selector resolver throws for an invalid selector", t => {
  let doc = WebAPI.Window.current->WebAPI.Window.document
  t
  ->expect(() => Client__Tool__SelectorResolver.resolveBySelector(~doc, ~selector="[")->ignore)
  ->Expect.toThrow
})
