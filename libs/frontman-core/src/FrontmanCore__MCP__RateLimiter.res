type t

type decision = Allowed | Rejected(int) | Failed

let requestLimit = 256
let windowMs = 60000
let principalLimit = 4096
let principalByteLimit = 8192

@new @module("./mcp-rate-limiter.mjs")
external make: unit => t = "RateLimiter"

@send @return(nullable)
external checkInternal: (t, string, float) => option<int> = "check"

@get
external byteLength: Uint8Array.t => int = "byteLength"

let check = (limiter, ~principal, ~nowMs=Date.now()): decision => {
  switch FrontmanBindings.WebStreams.makeTextEncoder()->FrontmanBindings.WebStreams.encode(
    principal,
  ) {
  | bytes if bytes->byteLength > principalByteLimit => Failed
  | _ =>
    switch limiter->checkInternal(principal, nowMs) {
    | None => Allowed
    | Some(retryAfter) if retryAfter > 0 => Rejected(retryAfter)
    | Some(_) => Failed
    }
  }
}
