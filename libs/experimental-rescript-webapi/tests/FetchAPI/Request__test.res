let req = Request.fromURL("https://example.com")

let blob = Blob.make(~blobParts=[])
let file = File.make(~fileBits=[], ~fileName="hello.txt")
let params = URLSearchParams.fromString("greeting=hello")
let formData = FormData.make()
let stream = ReadableStream.make()

let stringBody = BodyInit.fromString("hello")
let blobBody = BodyInit.fromBlob(blob)
let fileBody = BodyInit.fromFile(file)
let paramsBody = BodyInit.fromURLSearchParams(params)
let formDataBody = BodyInit.fromFormData(formData)
let streamBody = BodyInit.fromReadableStream(stream)

let req1 = Request.fromURL("https://example.com/api", ~init={method: "POST", body: stringBody})

let req2 = Request.fromRequest(req1)

let _blob: Blob.t = await req2->Request.clone->Request.blob

let formDataReq = Request.fromURL(
  "https://example.com/form",
  ~init={method: "POST", body: formDataBody},
)
let _formData: FormData.t = await formDataReq->Request.formData

Console.log(await req2->Request.text)
