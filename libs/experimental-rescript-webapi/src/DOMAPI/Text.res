open DOMAPI

include CharacterData.Impl({type t = text})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Text)
*/
@new
external make: (~data: string=?) => text = "Text"

/**
Splits data at the given offset and returns the remainder as Text node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Text/splitText)
*/
@send
external splitText: (text, int) => text = "splitText"
