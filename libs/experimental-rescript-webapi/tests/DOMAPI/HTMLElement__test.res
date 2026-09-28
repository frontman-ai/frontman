DomGlobal.document
->Document.querySelector("form")
->Null.toOption
->Option.forEach(form => {
  form->Element.scrollIntoViewWithOptions({behavior: DomTypes.Smooth})
})
