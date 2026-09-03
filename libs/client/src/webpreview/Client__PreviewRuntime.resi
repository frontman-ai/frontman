type t

let make: (~iframe: WebAPI.DomTypes.htmliFrameElement, ~targetOrigin: string, ~channel: string) => t
let status: t => Runtime.status
let onStatus: (t, Runtime.status => unit) => unit => unit
let whenOpen: t => Promise.t<unit>
let getDom: (
  t,
  FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview.getDomInput,
) => Promise.t<FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview.getDomOutput>
let close: t => unit
