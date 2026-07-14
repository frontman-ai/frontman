let headers = HeadersInit.fromDict(dict{"X-Fruit": "Peach"})
let blob = Blob.make(~blobParts=[])
let file = File.make(~fileBits=[], ~fileName="pong.txt")
let params = URLSearchParams.fromString("fruit=peach")
let formData = FormData.make()
let stream = ReadableStream.make()

let response = Response.fromNull(~init={status: 204, headers})

let response1 = Response.fromString("pong", ~init={status: 200, headers})

let response2 = Response.fromBlob(blob)
let response3 = Response.fromFile(file)
let response4 = Response.fromURLSearchParams(params)
let response5 = Response.fromFormData(formData)
let response6 = Response.fromReadableStream(stream)

let _blob: Blob.t = await response1
->Response.clone
->Response.blob
let _formData: FormData.t = await response5->Response.formData
