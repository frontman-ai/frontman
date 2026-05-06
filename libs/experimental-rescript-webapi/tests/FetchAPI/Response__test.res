Response.fromNull(~init={status: 204})->ignore

Response.fromString(
  "pong",
  ~init={status: 200, headers: HeadersInit.fromDict(dict{"X-Fruit": "Peach"})},
)->ignore
