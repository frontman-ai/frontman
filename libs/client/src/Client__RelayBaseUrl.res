// Build the public same-origin base URL used for /frontman/* requests.
//
// WordPress Playground mounts each site under a scoped path segment such as
// /scope:kind-hip-valley. If we drop that prefix and POST to /frontman/tools/call,
// Playground redirects to the scoped URL with a 302 and the browser retries as GET.
// Preserve the leading scope segment so tool calls stay POST requests.

let scopePrefixFromPathname = (pathname: string): option<string> => {
  let firstSegment = pathname->String.split("/")->Array.get(1)

  switch firstSegment {
  | Some(segment) =>
    switch segment->String.startsWith("scope:") {
    | true => Some(`/${segment}`)
    | false => None
    }
  | None => None
  }
}

let fromParts = (~protocol: string, ~host: string, ~pathname: string): string => {
  let origin = `${protocol}//${host}`

  switch scopePrefixFromPathname(pathname) {
  | Some(prefix) => `${origin}${prefix}`
  | None => origin
  }
}

let current = (): string => {
  let location = WebAPI.Global.location
  fromParts(~protocol=location.protocol, ~host=location.host, ~pathname=location.pathname)
}
