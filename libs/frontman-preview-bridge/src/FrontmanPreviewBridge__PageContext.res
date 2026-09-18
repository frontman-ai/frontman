module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

let read = (): Preview.pageContext => {
  let window = WebAPI.Window.current
  let colorScheme = switch (
    window->WebAPI.Window.matchMedia("(prefers-color-scheme: dark)")
  ).matches {
  | true => #dark
  | false => #light
  }
  {
    url: (window->WebAPI.Window.location).href,
    title: (window->WebAPI.Window.document).title,
    viewportWidth: window->WebAPI.Window.innerWidth,
    viewportHeight: window->WebAPI.Window.innerHeight,
    devicePixelRatio: window->WebAPI.Window.devicePixelRatio,
    scrollY: window->WebAPI.Window.scrollY->Float.toInt,
    colorScheme,
    astroClientRouting: FrontmanAiAstroBrowser.FrontmanAstroBrowser__ClientRouting.read(
      Some(window->WebAPI.Window.document),
    ),
  }
}
