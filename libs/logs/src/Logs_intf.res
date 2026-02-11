module type Intf = {
  module Level = Logs_level
  type messageType = string

  let overrideLogLevel: Logs_level.t => unit

  let error: (
    ~ctx: {..}=?,
    ~stacktrace: option<string>=?,
    ~error: option<JsExn.t>=?,
    messageType,
  ) => unit
  let warning: (~ctx: {..}=?, messageType) => unit
  let info: (~ctx: {..}=?, messageType) => unit
  let debug: (~ctx: {..}=?, messageType) => unit
}

module type Base = {
  let component: [> LogComponent.t]
}
