/* This works when your form has an id of "myForm" */
@scope(("document", "forms"))
external myForm: DOMAPI.htmlFormElement = "myForm"

let formData = FormData.make(~form=myForm)
let phone: null<string> = formData->FormData.get("phone")
let image: null<FileAPI.file> = formData->FormData.getFile("image")
