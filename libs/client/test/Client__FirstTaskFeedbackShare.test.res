open Vitest

module Share = Client__FirstTaskFeedbackShare

external asExn: WebAPI.DOMException.t => exn = "%identity"

let rejected = name => Promise.reject(WebAPI.DOMException.make(~message="blocked", ~name)->asExn)

describe("first task feedback sharing", () => {
  testAsync("shares through the native share API when supported", async t => {
    let shared = ref(false)
    let copied = ref(false)
    let failed = ref(false)

    await Share.runWith(
      ~nativeShare=Some(_ => Promise.resolve()),
      ~canNativeShare=Some(_ => true),
      ~writeText=_ => Promise.resolve(),
      ~onShared=() => shared := true,
      ~onCopied=() => copied := true,
      ~onFailed=() => failed := true,
    )

    t->expect(shared.contents)->Expect.toBe(true)
    t->expect(copied.contents)->Expect.toBe(false)
    t->expect(failed.contents)->Expect.toBe(false)
  })

  testAsync("copies when native sharing rejects for a reason other than cancellation", async t => {
    let copied = ref(false)
    let failed = ref(false)

    await Share.runWith(
      ~nativeShare=Some(_ => rejected("NotAllowedError")),
      ~canNativeShare=Some(_ => true),
      ~writeText=_ => Promise.resolve(),
      ~onShared=() => (),
      ~onCopied=() => copied := true,
      ~onFailed=() => failed := true,
    )

    t->expect(copied.contents)->Expect.toBe(true)
    t->expect(failed.contents)->Expect.toBe(false)
  })

  testAsync("copies when the share payload is unsupported", async t => {
    let nativeShareCalled = ref(false)
    let copied = ref(false)

    await Share.runWith(
      ~nativeShare=Some(
        _ => {
          nativeShareCalled := true
          Promise.resolve()
        },
      ),
      ~canNativeShare=Some(_ => false),
      ~writeText=_ => Promise.resolve(),
      ~onShared=() => (),
      ~onCopied=() => copied := true,
      ~onFailed=() => (),
    )

    t->expect(nativeShareCalled.contents)->Expect.toBe(false)
    t->expect(copied.contents)->Expect.toBe(true)
  })

  testAsync("does nothing when the user cancels native sharing", async t => {
    let copied = ref(false)
    let failed = ref(false)

    await Share.runWith(
      ~nativeShare=Some(_ => rejected("AbortError")),
      ~canNativeShare=Some(_ => true),
      ~writeText=_ => Promise.resolve(),
      ~onShared=() => (),
      ~onCopied=() => copied := true,
      ~onFailed=() => failed := true,
    )

    t->expect(copied.contents)->Expect.toBe(false)
    t->expect(failed.contents)->Expect.toBe(false)
  })

  testAsync("reports failure when clipboard fallback rejects", async t => {
    let failed = ref(false)

    await Share.runWith(
      ~nativeShare=None,
      ~canNativeShare=None,
      ~writeText=_ => rejected("NotAllowedError"),
      ~onShared=() => (),
      ~onCopied=() => (),
      ~onFailed=() => failed := true,
    )

    t->expect(failed.contents)->Expect.toBe(true)
  })
})
