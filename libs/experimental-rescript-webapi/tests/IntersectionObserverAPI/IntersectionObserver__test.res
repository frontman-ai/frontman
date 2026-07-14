module IObserver = IntersectionObserver
module IRoot = IntersectionObserverRoot

let observer = IObserver.make(~callback=(entry, observer) => {
  Console.log2(entry, observer)
})

let root = DomGlobal.document->Document.querySelector("#root")->Null.getUnsafe

let observer2 = IObserver.make(
  ~callback=(entry, observer) => {
    Console.log2(entry, observer)
  },
  ~options={
    root: root->IRoot.fromElement,
    rootMargin: "10px",
    threshold: [0.1],
  },
)

switch observer2.root->IRoot.decode {
| Element(_) => Console.log("Element")
| Document(_) => Console.log("Document")
| Null => Console.log("Null")
}
let rootMargin2 = observer2.rootMargin

let targetElement = DomGlobal.document->Document.querySelector("#targetElement")->Null.toOption
switch targetElement {
| Some(e) => {
    observer2->IObserver.observe(e)
    observer2->IObserver.unobserve(e)
  }
| _ => Console.log("Target element not found.")
}

let entries2 = observer2->IObserver.takeRecords
Console.log(entries2->Array.length)

observer2->IObserver.disconnect
