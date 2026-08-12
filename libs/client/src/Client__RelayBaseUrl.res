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

let fromParts = (
  ~protocol: string,
  ~host: string,
  ~pathname: string,
  ~routePrefix: string="",
): string => {
  let origin = `${protocol}//${host}`

  switch routePrefix {
  | "" =>
    switch scopePrefixFromPathname(pathname) {
    | Some(prefix) => `${origin}${prefix}`
    | None => origin
    }
  | prefix => `${origin}${prefix}`
  }
}

let current = (~routePrefix: string=""): string => {
  let location = WebAPI.Global.location
  fromParts(
    ~protocol=location.protocol,
    ~host=location.host,
    ~pathname=location.pathname,
    ~routePrefix,
  )
}
