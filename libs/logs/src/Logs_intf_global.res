module type IntfGlobal = {
  module Level = Logs_level

  type messageType = string

  let overrideLogLevel: Logs_level.t => unit

  let error: (
    ~ctx: {..}=?,
    ~error: option<JsExn.t>=?,
    ~stacktrace: option<string>=?,
    ~component: LogComponent.t,
    messageType,
  ) => unit
  let warning: (~ctx: {..}=?, ~component: LogComponent.t, messageType) => unit
  let info: (~ctx: {..}=?, ~component: LogComponent.t, messageType) => unit
  let debug: (~ctx: {..}=?, ~component: LogComponent.t=?, messageType) => unit
}
