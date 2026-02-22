// Shared CORS helpers for all framework adapters

// CORS headers for cross-origin requests
let corsHeaders = Dict.fromArray([
  ("Access-Control-Allow-Origin", "*"),
  ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
  ("Access-Control-Allow-Headers", "Content-Type"),
])

// Add CORS headers to a response
let withCors = (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let headers = response.headers
  corsHeaders->Dict.forEachWithKey((value, key) => {
    headers->WebAPI.Headers.set(~name=key, ~value)
  })
  response
}

// Handle OPTIONS preflight request
let handlePreflight = (): WebAPI.FetchAPI.response => {
  let headers = WebAPI.HeadersInit.fromDict(corsHeaders)
  WebAPI.Response.fromNull(~init={status: 204, headers})
}
