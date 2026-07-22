open Vitest

describe("Client__UpdateBanner", _t => {
  test("includes projectRoot in the update prompt", t => {
    let prompt = Client__UpdateBanner.updatePrompt(
      ~npmPackage="@frontman-ai/nextjs",
      ~installedVersion="1.0.0",
      ~latestVersion="1.1.0",
      ~projectRoot=Some("/workspace/apps/web"),
    )

    t
    ->expect(prompt->String.includes("The project root is /workspace/apps/web."))
    ->Expect.toBe(true)
  })
})
