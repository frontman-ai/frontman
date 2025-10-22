open WebAPI
open WebAPI.Global

document
->Document.querySelector("form")
->Null.toOption
->Option.forEach(form => {
  form->Element.scrollIntoViewWithOptions({behavior: DOMAPI.Smooth})
})
