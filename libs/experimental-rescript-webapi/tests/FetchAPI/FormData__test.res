@scope(("document", "forms"))
external myForm: HTMLFormElement.t = "myForm"

module EntryValue = FormDataEntryValue

open EntryValue

let logEntry = (~stringPrefix: string, ~filePrefix: string, entry: EntryValue.t) =>
  switch entry {
  | String(value) => Console.log(`${stringPrefix}${value}`)
  | File(file) => Console.log(`${filePrefix}${file.name}`)
  }

let formData: FormData.t = FormData.make(~form=myForm)

let phoneEntry: null<EntryValue.t> = formData->FormData.get("phone")

let _ = switch phoneEntry->Null.toOption {
| None => Console.log("No phone field")
| Some(entry) => logEntry(~stringPrefix="Phone: ", ~filePrefix="Unexpected file: ", entry)
}

let allImages: array<EntryValue.t> = formData->FormData.getAll("images")
let _ =
  allImages->Array.forEach(entry =>
    logEntry(~stringPrefix="String value: ", ~filePrefix="WebApiFile: ", entry)
  )

let stringEntry = EntryValue.String("test value")
let blob: Blob.t = Blob.make(~blobParts=[])
let file: File.t = File.make(~fileBits=[], ~fileName="test.txt")
let fileEntry = EntryValue.File(file)

formData->FormData.appendBlob(~name="avatar", ~blobValue=blob)

logEntry(~stringPrefix="String entry: ", ~filePrefix="Unexpected file entry: ", stringEntry)

logEntry(~stringPrefix="Unexpected string entry: ", ~filePrefix="File entry: ", fileEntry)

let entries: Iterator.t<(string, EntryValue.t)> = formData->FormData.entries
let _ =
  entries
  ->Array.fromIterator
  ->Array.forEach(((key, value)) => {
    switch value {
    | String(s) => Console.log(`${key}: ${s}`)
    | File(f) => Console.log(`${key}: [WebApiFile] ${f.name}`)
    }
  })
