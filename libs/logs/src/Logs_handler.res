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

@inline
let run = h => h.run
