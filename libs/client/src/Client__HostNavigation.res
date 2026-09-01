@val external browserTopWindow: WebAPI.DomTypes.window = "top"
@get external locationHref: WebAPI.DomTypes.location => string = "href"

let useTopWindow = (
  ~currentWindow: WebAPI.DomTypes.window,
  ~topWindow: WebAPI.DomTypes.window,
): bool => currentWindow !== topWindow

let returnUrl = (~currentUrl: string, ~topUrl: option<string>, ~useTopWindow: bool): string =>
  switch (useTopWindow, topUrl) {
  | (true, Some(url)) => url
  | _ => currentUrl
  }

let currentUrl = (): string => {
  let currentWindow = WebAPI.Window.current
  let topWindow = browserTopWindow
  let currentUrl = currentWindow->WebAPI.Window.location->locationHref
  let shouldUseTopWindow = useTopWindow(~currentWindow, ~topWindow)

  switch shouldUseTopWindow {
  | true =>
    try {
      returnUrl(
        ~currentUrl,
        ~topUrl=Some(topWindow->WebAPI.Window.location->locationHref),
        ~useTopWindow=shouldUseTopWindow,
      )
    } catch {
    | _ => returnUrl(~currentUrl, ~topUrl=None, ~useTopWindow=shouldUseTopWindow)
    }
  | false => currentUrl
  }
}

let assign = (~url: string) => {
  let currentWindow = WebAPI.Window.current
  let topWindow = browserTopWindow

  switch useTopWindow(~currentWindow, ~topWindow) {
  | true =>
    try {
      topWindow->WebAPI.Window.location->WebAPI.Location.assign(url)
    } catch {
    | _ => currentWindow->WebAPI.Window.location->WebAPI.Location.assign(url)
    }
  | false => currentWindow->WebAPI.Window.location->WebAPI.Location.assign(url)
  }
}
