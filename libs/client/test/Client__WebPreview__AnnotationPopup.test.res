open Vitest

module Popup = Client__WebPreview__AnnotationPopup

describe("annotation popup execution readiness", () => {
  test("allows execution only when chat and annotations are ready", t => {
    t
    ->expect(
      Popup.canExecute(
        ~hasActiveACPSession=true,
        ~selectedAgentId=Some("agent"),
        ~selectedModelValue=Some("model"),
        ~providerSetupRequired=false,
        ~hasEnrichingAnnotations=false,
      ),
    )
    ->Expect.toBe(true)

    [
      Popup.canExecute(
        ~hasActiveACPSession=false,
        ~selectedAgentId=Some("agent"),
        ~selectedModelValue=Some("model"),
        ~providerSetupRequired=false,
        ~hasEnrichingAnnotations=false,
      ),
      Popup.canExecute(
        ~hasActiveACPSession=true,
        ~selectedAgentId=None,
        ~selectedModelValue=Some("model"),
        ~providerSetupRequired=false,
        ~hasEnrichingAnnotations=false,
      ),
      Popup.canExecute(
        ~hasActiveACPSession=true,
        ~selectedAgentId=Some("agent"),
        ~selectedModelValue=None,
        ~providerSetupRequired=false,
        ~hasEnrichingAnnotations=false,
      ),
      Popup.canExecute(
        ~hasActiveACPSession=true,
        ~selectedAgentId=Some("agent"),
        ~selectedModelValue=Some("model"),
        ~providerSetupRequired=true,
        ~hasEnrichingAnnotations=false,
      ),
      Popup.canExecute(
        ~hasActiveACPSession=true,
        ~selectedAgentId=Some("agent"),
        ~selectedModelValue=Some("model"),
        ~providerSetupRequired=false,
        ~hasEnrichingAnnotations=true,
      ),
    ]->Array.forEach(result => t->expect(result)->Expect.toBe(false))
  })
})
