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
  let location = WebAPI.Window.current->WebAPI.Window.location
  fromParts(~protocol=location.protocol, ~host=location.host, ~pathname=location.pathname)
}
