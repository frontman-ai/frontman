open DOMAPI

include HTMLElement.Impl({type t = htmliFrameElement})

@send
external getSVGDocument: htmliFrameElement => document = "getSVGDocument"

@send
external contentDocument: htmliFrameElement => Null.t<document> = "contentDocument"