module C = {
  type t
  @val external console: t = "console"
  @send external debug: (t, string, string, string, string, 'a) => unit = "debug"
  @send external info: (t, string, string, string, string, 'a) => unit = "info"
  @send external warn: (t, string, string, string, string, 'a) => unit = "warn"
  @send external error: (t, string, string, string, string, 'a) => unit = "error"
}

let __use_colors__ = ref(true)

let useColors = x => {
  __use_colors__ := x
}

let now = () => Date.make()->Date.toISOString

let color = Math.Int.random(0, 360)->Int.toString

let rounding = "3px"

let app_style = () =>
  if __use_colors__.contents {
    `border-radius: ${rounding}; background-color: hsl(${color}deg 100% 35%); color: #ffffff; padding: 0.2em 0.4em; margin: 0 0.5em;`
  } else {
    ``
  }

let level_style = color =>
  if __use_colors__.contents {
    `border-radius: ${rounding}; background-color: ${color}; color: #ffffff; padding: 0.2em 0.4em; margin-left: 0.2rem;`
  } else {
    ``
  }

let text_style = () =>
  if __use_colors__.contents {
    "margin-left: 0.2rem; background-color: rgba(0,0,0,0); "
  } else {
    ``
  }

let error = (component, line, ctx, _err) => {
  C.error(
    C.console,
    now() ++ `%cERROR%c` ++ component ++ `%c` ++ line,
    level_style("#ff4444"),
    app_style(),
    text_style(),
    ctx,
  )
}

let debug = (component, line, ctx) => {
  C.debug(
    C.console,
    now() ++ `%cDEBUG%c` ++ component ++ `%c` ++ line,
    level_style("#121212"),
    app_style(),
    text_style(),
    ctx,
  )
}

let warn = (component, line, ctx) => {
  C.warn(
    C.console,
    now() ++ `%cWARN%c` ++ component ++ `%c` ++ line,
    level_style("#2c9dbf"),
    app_style(),
    text_style(),
    ctx,
  )
}

let info = (component, line, ctx) => {
  C.info(
    C.console,
    now() ++ `%cINFO%c` ++ component ++ `%c` ++ line,
    level_style("#2c9dbf"),
    app_style(),
    text_style(),
    ctx,
  )
}

let handler: Logs_handler.t = {
  id: "browser-console",
  run: (~component, ~stacktrace as _, ~level, line, ctx, err) => {
    switch level {
    | Logs_level.Info => info(component, line, ctx)
    | Logs_level.Debug => debug(component, line, ctx)
    | Logs_level.Warning => warn(component, line, ctx)
    | Logs_level.Error => error(component, line, ctx, err)
    }
  },
}
