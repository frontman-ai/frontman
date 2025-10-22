open WebAPI
open WebAPI.Global

let button = document->Document.querySelector("button")->Null.toOption
let h2 = document->Document.querySelector("h2")->Null.toOption

switch (button, h2) {
| (Some(button), Some(h2)) =>
  button->Element.addEventListener(EventAPI.Click, (e: UIEventsAPI.mouseEvent) => {
    Console.log(`Button clicked, ${Int.toString(e.button)}`)
    switch h2.textContent {
    | Null => h2.textContent = Value("1")
    | Value(text) =>
      switch Int.fromString(text) {
      | None => h2.textContent = Value("1")
      | Some(number) => h2.textContent = Value(Int.toString(number + 1))
      }
    }
  })
| _ => Console.log("Stuff not found")
}
