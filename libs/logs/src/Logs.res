module Handler = Logs_handler
module Console = Logs_console

external objAssign: ({..}, {..}) => {..} = "Object.assign"

let empty = (): {..} => %raw("{}")

let __handlers__: array<Handler.t> = []

let __log_level__ = ref(Logs_level.default)

let __context__ = ref(empty())

let addHandler = (h: Handler.t) => {
  if !(__handlers__->Array.some(existing => existing.id == h.id)) {
    __handlers__->Array.push(h)
  }
}

let setLogLevel = x => {
  __log_level__ := x
}

let getLogLevel = () => {
  __log_level__.contents
}

let addGlobalContext = ctx => {
  let copyContext = objAssign(empty(), __context__.contents)
  __context__ := objAssign(copyContext, ctx)
}

let getGlobalContext = () => {
  objAssign(empty(), __context__.contents)
}

let prepareContext = ctx => {
  let copyContext = objAssign(empty(), __context__.contents)
  objAssign(copyContext, ctx)
}

include Logs_intf
module Make = (B: Logs_intf.Base): Logs_intf.Intf => {
  module Level = Logs_level

  type messageType = string

  let component = B.component

  let level = ref(None)

  let overrideLogLevel = x => {
    level := Some(x)
  }

  let shouldLog = l2 => {
    let l1 = switch level.contents {
    | None => __log_level__.contents
    | Some(level) => level
    }
    Level.shouldLog(l1, l2)
  }

  let log = (~ctx, ~stacktrace=None, ~error=None, level, message) => {
    if shouldLog(level) {
      let context = prepareContext(ctx)
      __handlers__->Array.forEach(handler => {
        handler.run(
          ~component=LogComponent.componentToString(component),
          ~level,
          ~stacktrace,
          message,
          context,
          error,
        )
      })
    }
  }

  let error = (~ctx=empty(), ~stacktrace=None, ~error=None, message) =>
    log(~ctx, ~stacktrace, ~error, Error, message)

  let warning = (~ctx=empty(), message) => log(~ctx, Warning, message)

  let info = (~ctx=empty(), message) => log(~ctx, Info, message)

  let debug = (~ctx=empty(), message) => log(~ctx, Debug, message)
}

include Logs_intf_global
module MakeGlobal = (): Logs_intf_global.IntfGlobal => {
  module Level = Logs_level

  type messageType = string

  let level = ref(None)

  let overrideLogLevel = x => {
    level := Some(x)
  }

  let shouldLog = l2 => {
    let l1 = switch level.contents {
    | None => __log_level__.contents
    | Some(level) => level
    }
    Level.shouldLog(l1, l2)
  }

  let log = (~ctx, ~stacktrace=None, ~error=None, level, message, component) => {
    if shouldLog(level) {
      let context = prepareContext(ctx)
      __handlers__->Array.forEach(handler => {
        handler.run(
          ~component=LogComponent.componentToString(component),
          ~level,
          ~stacktrace,
          message,
          context,
          error,
        )
      })
    }
  }

  let error = (~ctx=empty(), ~error=None, ~stacktrace=None, ~component, message) =>
    log(~ctx, ~error, ~stacktrace, Error, message, component)

  let warning = (~ctx=empty(), ~component, message) => log(~ctx, Warning, message, component)

  let info = (~ctx=empty(), ~component, message) => log(~ctx, Info, message, component)

  let debug = (~ctx=empty(), ~component=#Global, message) =>
    log(~ctx, Debug, message, component)
}

include MakeGlobal()
