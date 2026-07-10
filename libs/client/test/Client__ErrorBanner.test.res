open Vitest

describe("ErrorBanner quota guidance", () => {
  test("formats quota reset guidance with relative and local absolute time", t => {
    let nowMs = Date.fromString("2025-01-15T10:00:00Z")->Date.getTime
    let resetMs = nowMs +. (3.0 *. 60.0 +. 12.0) *. 60.0 *. 1000.0

    let guidance = Client__ErrorBanner.quotaGuidance(~retryAvailableAt=Some(resetMs), ~nowMs)

    switch guidance {
    | Some(text) => {
        t->expect(text->String.startsWith("Quota resets in 3h 12m, after "))->Expect.toBe(true)
        t->expect(text->String.includes(":"))->Expect.toBe(true)
      }
    | None => t->expect("guidance")->Expect.toBe("missing")
    }
  })

  test("formats quota guidance fallback when reset time is missing", t => {
    let guidance = Client__ErrorBanner.quotaGuidance(~retryAvailableAt=None, ~nowMs=0.0)

    t
    ->expect(guidance)
    ->Expect.toEqual(
      Some("Quota limit reached. Try again later or configure a different provider."),
    )
  })
})

describe("ErrorBanner action policy", () => {
  let policy = category =>
    Client__ErrorBanner.presentation(~category, ~retryAvailableAt=None, ~nowMs=0.0)

  test("sets retry copy and provider configuration priority by category", t => {
    let quotaPolicy = policy(#quota)
    let rateLimitPolicy = policy(#rate_limit)

    t->expect(quotaPolicy.retryLabel)->Expect.toBe("Retry anyway")
    t->expect(quotaPolicy.configureProviderFirst)->Expect.toBe(true)
    t->expect(policy(#auth).configureProviderFirst)->Expect.toBe(true)
    t->expect(policy(#billing).configureProviderFirst)->Expect.toBe(true)
    t->expect(rateLimitPolicy.retryLabel)->Expect.toBe("Retry")
    t->expect(rateLimitPolicy.configureProviderFirst)->Expect.toBe(false)
  })
})
