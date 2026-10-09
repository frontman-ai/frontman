let window = WebAPI.Window.current
FrontmanPreviewBridge__Bootstrap.fromFrame(
  ~name=window->WebAPI.Window.name,
  ~origin=(window->WebAPI.Window.location).origin,
  ~isTopLevel=window == window->WebAPI.Window.parent,
)->Option.forEach(config => FrontmanPreviewBridge.install(config)->ignore)
