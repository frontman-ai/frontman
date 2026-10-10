let fromFrame = (~name: string, ~origin: string, ~isTopLevel: bool): option<
  FrontmanPreviewBridge.config,
> =>
  switch isTopLevel || !(name->String.startsWith("frontman:")) {
  | true => None
  | false =>
    let config = WebAPI.URL.make(~url=name->String.slice(~start=9, ~end=String.length(name)))
    let channel = config.searchParams->WebAPI.URLSearchParams.get("channel")->Null.toOption
    switch (config.protocol, channel) {
    | ("http:" | "https:", Some(channel)) if channel != "" =>
      switch config.origin == origin {
      | true => Some({parentOrigin: origin, channel})
      | false => None
      }
    | _ => JsError.throwWithMessage("Invalid Frontman preview frame configuration")
    }
  }
