external fetch: (string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"

external fetchWithRequest: (Request.t, ~init: Request.requestInit=?) => promise<Response.t> =
  "fetch"
