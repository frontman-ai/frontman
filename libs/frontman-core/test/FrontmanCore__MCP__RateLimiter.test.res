open Vitest

module RateLimiter = FrontmanCore__MCP__RateLimiter

describe("MCP rate limiter", _t => {
  test("accepts request 256, rejects request 257, and resets at exact expiry", t => {
    let limiter = RateLimiter.make()
    for _request in 1 to RateLimiter.requestLimit {
      t
      ->expect(limiter->RateLimiter.check(~principal="principal-a", ~nowMs=1000.))
      ->Expect.toEqual(RateLimiter.Allowed)
    }

    t
    ->expect(limiter->RateLimiter.check(~principal="principal-a", ~nowMs=1000.))
    ->Expect.toEqual(RateLimiter.Rejected(60))
    t
    ->expect(limiter->RateLimiter.check(~principal="principal-a", ~nowMs=60999.))
    ->Expect.toEqual(RateLimiter.Rejected(1))
    t
    ->expect(limiter->RateLimiter.check(~principal="principal-a", ~nowMs=61000.))
    ->Expect.toEqual(RateLimiter.Allowed)
  })

  test("isolates principals and fails closed at bounded principal capacity", t => {
    let limiter = RateLimiter.make()
    for index in 1 to RateLimiter.principalLimit {
      t
      ->expect(limiter->RateLimiter.check(~principal=`principal-${index->Int.toString}`, ~nowMs=0.))
      ->Expect.toEqual(RateLimiter.Allowed)
    }
    t
    ->expect(limiter->RateLimiter.check(~principal="principal-over", ~nowMs=0.))
    ->Expect.toEqual(RateLimiter.Failed)
    t
    ->expect(limiter->RateLimiter.check(~principal="principal-over", ~nowMs=60000.))
    ->Expect.toEqual(RateLimiter.Allowed)
  })

  test("fails closed for invalid time and oversized principal keys", t => {
    let limiter = RateLimiter.make()
    t
    ->expect(limiter->RateLimiter.check(~principal="principal", ~nowMs=-1.))
    ->Expect.toEqual(RateLimiter.Failed)
    t
    ->expect(
      limiter->RateLimiter.check(
        ~principal="x"->String.repeat(RateLimiter.principalByteLimit + 1),
        ~nowMs=0.,
      ),
    )
    ->Expect.toEqual(RateLimiter.Failed)
  })
})
