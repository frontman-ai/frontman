let req = Request.fromURL("https://example.com")

let req1 = Request.fromURL(
  "https://example.com/api",
  ~init={method: "POST", body: BodyInit.fromString("hello")},
)

let req2 = Request.fromRequest(req1)

Console.log(await req2->Request.text)
