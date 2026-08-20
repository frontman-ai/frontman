type t

let make: (~iframe: WebAPI.DomTypes.htmliFrameElement, ~targetOrigin: string, ~channel: string) => t
let status: t => Runtime.status
let onStatus: (t, Runtime.status => unit) => unit => unit
let whenOpen: t => Promise.t<unit>
let close: t => unit
