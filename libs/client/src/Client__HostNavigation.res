let useTopWindow = (~currentWindow: WebAPI.DOMAPI.window, ~topWindow: WebAPI.DOMAPI.window): bool =>
  currentWindow !== topWindow

type loginNavigation =
  | CurrentWindow
  | NewWindow

let loginNavigation = (~currentWindow: WebAPI.DOMAPI.window, ~topWindow: WebAPI.DOMAPI.window) =>
  switch useTopWindow(~currentWindow, ~topWindow) {
  | true => NewWindow
  | false => CurrentWindow
  }

let popupOpened = popup => popup->Nullable.toOption->Option.isSome

let returnUrl = (~currentUrl: string, ~topUrl: option<string>, ~useTopWindow: bool): string =>
  switch (useTopWindow, topUrl) {
  | (true, Some(url)) => url
  | _ => currentUrl
  }

let currentUrl = (): string => {
  let currentWindow = WebAPI.Global.window
  let topWindow = WebAPI.Global.top
  let currentUrl = currentWindow->WebAPI.Window.location->WebAPI.Location.href
  let shouldUseTopWindow = useTopWindow(~currentWindow, ~topWindow)

  switch shouldUseTopWindow {
  | true =>
    try {
      returnUrl(
        ~currentUrl,
        ~topUrl=Some(topWindow->WebAPI.Window.location->WebAPI.Location.href),
        ~useTopWindow=shouldUseTopWindow,
      )
    } catch {
    | _ => returnUrl(~currentUrl, ~topUrl=None, ~useTopWindow=shouldUseTopWindow)
    }
  | false => currentUrl
  }
}

let assign = (~url: string) => {
  let currentWindow = WebAPI.Global.window
  let topWindow = WebAPI.Global.top

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

let openLogin = (~url: string): bool => {
  let currentWindow = WebAPI.Global.window

  switch loginNavigation(~currentWindow, ~topWindow=WebAPI.Global.top) {
  | CurrentWindow =>
    currentWindow->WebAPI.Window.location->WebAPI.Location.assign(url)
    true
  | NewWindow =>
    let popup = currentWindow->WebAPI.Window.open_(~url, ~target="_blank", ~features="")
    switch popup->Nullable.toOption {
    | Some(loginWindow) =>
      loginWindow->WebAPI.Window.setOpener(Nullable.null)
      true
    | None => false
    }
  }
}
