open DOMAPI

include HTMLElement.Impl({type t = htmliFrameElement})

@send
external getSVGDocument: htmliFrameElement => document = "getSVGDocument"

@get @return(nullable)
external contentDocument: htmliFrameElement => option<document> = "contentDocument"

@get @return(nullable)
external contentWindow: htmliFrameElement => option<WebAPI.DOMAPI.window> = "contentWindow"
