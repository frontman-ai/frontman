@send
external request: (
  WebLocksTypes.lockManager,
  ~name: string,
  ~callback: WebLocksTypes.lockGrantedCallback,
) => promise<JSON.t> = "request"

@send
external request2: (
  WebLocksTypes.lockManager,
  ~name: string,
  ~options: WebLocksTypes.lockOptions,
  ~callback: WebLocksTypes.lockGrantedCallback,
) => promise<JSON.t> = "request"

@send
external query: WebLocksTypes.lockManager => promise<WebLocksTypes.lockManagerSnapshot> = "query"
