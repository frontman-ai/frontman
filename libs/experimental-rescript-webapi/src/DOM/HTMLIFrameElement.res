include HTMLElement.Impl({type t = DomTypes.htmliFrameElement})

@get @return(nullable)
external contentDocument: DomTypes.htmliFrameElement => option<DomTypes.document> =
  "contentDocument"

@get @return(nullable)
external contentWindow: DomTypes.htmliFrameElement => option<DomTypes.window> = "contentWindow"

@send
external getSVGDocument: DomTypes.htmliFrameElement => DomTypes.document = "getSVGDocument"
