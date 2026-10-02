type managedTab = WebAPI.Window.t

let openManagedTab = (~url: string): option<managedTab> => {
  WebAPI.Window.current
  ->FrontmanBindings.BrowserWindow.openNullable(~url="about:blank", ~target="_blank")
  ->Nullable.toOption
  ->Option.map(tab => {
    tab->FrontmanBindings.BrowserWindow.setOpener(Nullable.null)
    tab->WebAPI.Window.location->WebAPI.Location.assign(url)
    tab
  })
}
