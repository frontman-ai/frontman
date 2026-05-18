// Navigate the host page, escaping an embedding iframe when needed.
// This keeps hosted auth flows working in shells like WordPress Playground.

type managedTab = FrontmanBindings.BrowserWindow.managedTab

let useTopWindow = (~currentWindow: WebAPI.DOMAPI.window, ~topWindow: WebAPI.DOMAPI.window): bool =>
  currentWindow !== topWindow

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

let openManagedTab = (~url: string): option<managedTab> => {
  let currentWindow = WebAPI.Global.window

  currentWindow
  ->FrontmanBindings.BrowserWindow.openNullable(~url="about:blank", ~target="_blank")
  ->Nullable.toOption
  ->Option.map(tab => {
    tab->FrontmanBindings.BrowserWindow.setOpener(Nullable.null)
    tab->WebAPI.Window.location->WebAPI.Location.assign(url)
    tab
  })
}

let tabClosed = (tab: managedTab): bool => {
  try {
    tab->FrontmanBindings.BrowserWindow.closed
  } catch {
  | _ => true
  }
}
