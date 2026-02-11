module Make: (B: Logs_intf.Base) => Logs_intf.Intf

include Logs_intf_global.IntfGlobal

let setLogLevel: Logs_level.t => unit

let getLogLevel: unit => Logs_level.t

let addGlobalContext: {..} => unit

let getGlobalContext: unit => {..}

let prepareContext: {..} => {..}

module Handler: {
  type t = {
    id: string,
    run: 'a. (
      ~component: string,
      ~stacktrace: option<string>,
      ~level: Logs_level.t,
      string,
      'a,
      option<JsExn.t>,
    ) => unit,
  }
}

let addHandler: Handler.t => unit

module Console: {
  let useColors: bool => unit
  let handler: Handler.t
}
