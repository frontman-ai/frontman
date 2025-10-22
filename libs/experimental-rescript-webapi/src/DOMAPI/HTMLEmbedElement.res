open DOMAPI

include HTMLElement.Impl({type t = htmlEmbedElement})

@send
external getSVGDocument: htmlEmbedElement => document = "getSVGDocument"
