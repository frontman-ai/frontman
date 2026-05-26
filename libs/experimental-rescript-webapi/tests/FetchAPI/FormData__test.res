/* This works when your form has an id of "myForm" */
@scope(("document", "forms"))
external myForm: DOMAPI.htmlFormElement = "myForm"

let formData = FormData.make(~form=myForm)
(formData->FormData.get("phone"): null<string>)->ignore
(formData->FormData.getFile("image"): null<FileAPI.file>)->ignore
