@@warning("-30")

@editor.completeFrom(URLSearchParams)
type urlSearchParams = private {
  size: int,
}

@editor.completeFrom(WebApiURL)
type url = {
  mutable href: string,
  origin: string,
  mutable protocol: string,
  mutable username: string,
  mutable password: string,
  mutable host: string,
  mutable hostname: string,
  mutable port: string,
  mutable pathname: string,
  mutable search: string,
  searchParams: urlSearchParams,
  mutable hash: string,
}
