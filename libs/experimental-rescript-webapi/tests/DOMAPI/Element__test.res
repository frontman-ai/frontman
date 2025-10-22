external myElement: DOMAPI.element = "myElement"

switch myElement->Element.getAttribute("foo") {
| Null.Value(value) => value->Console.log
| Null => "nothing"->Console.log
}
