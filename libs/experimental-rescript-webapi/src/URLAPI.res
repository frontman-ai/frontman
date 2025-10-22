@@warning("-30")

/**
[See URLSearchParams on MDN](https://developer.mozilla.org/docs/Web/API/URLSearchParams)
*/
@editor.completeFrom(URLSearchParams)
type urlSearchParams = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URLSearchParams/size)
    */
  size: int,
}

/**
The URL interface represents an object providing static methods used for creating object URLs.
[See URL on MDN](https://developer.mozilla.org/docs/Web/API/URL)
*/
@editor.completeFrom(URL)
type url = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/href)
    */
  mutable href: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/origin)
    */
  origin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/protocol)
    */
  mutable protocol: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/username)
    */
  mutable username: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/password)
    */
  mutable password: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/host)
    */
  mutable host: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/hostname)
    */
  mutable hostname: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/port)
    */
  mutable port: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/pathname)
    */
  mutable pathname: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/search)
    */
  mutable search: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/searchParams)
    */
  searchParams: urlSearchParams,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/hash)
    */
  mutable hash: string,
}
