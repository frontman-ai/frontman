module MObserver = MutationObserver

let observer = MObserver.make((mutations, obs) => {
  let button = DomGlobal.document->Document.querySelector("button")
  switch button->Null.toOption {
  | Some(button) => {
      Console.log(button)
      obs->MObserver.disconnect
    }
  | None => ()
  }
  Console.log(mutations)
})

observer->MObserver.observe(
  ~target=DomGlobal.document->Document.asNode,
  ~options={childList: true, subtree: true},
)

let records = observer->MObserver.takeRecords
Console.log(records->Array.length)

observer->MObserver.disconnect
