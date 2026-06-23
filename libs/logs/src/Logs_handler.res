type t = {
  @live
  id: string,
  @live
  run: 'a. (
    ~component: string,
    ~stacktrace: option<string>,
    ~level: Logs_level.t,
    string,
    'a,
    option<JsExn.t>,
  ) => unit,
}

@@live
let run = h => h.run
