@send
external go: (HistoryTypes.history, ~delta: int=?) => unit = "go"

@send
external back: HistoryTypes.history => unit = "back"

@send
external forward: HistoryTypes.history => unit = "forward"

@send
external pushState: (HistoryTypes.history, ~data: JSON.t, ~unused: string, ~url: string=?) => unit =
  "pushState"

@send
external replaceState: (
  HistoryTypes.history,
  ~data: JSON.t,
  ~unused: string,
  ~url: string=?,
) => unit = "replaceState"

module Types = HistoryTypes
