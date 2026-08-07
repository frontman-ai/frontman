include CharacterData.Impl({type t = DomTypes.text})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Text)
*/
@new
external make: (~data: string=?) => DomTypes.text = "Text"

/**
Splits data at the given offset and returns the remainder as Text node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Text/splitText)
*/
@send
external splitText: (DomTypes.text, int) => DomTypes.text = "splitText"
