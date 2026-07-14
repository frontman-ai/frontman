include CharacterData.Impl({type t = DomTypes.comment})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Comment)
*/
@new
external make: (~data: string=?) => DomTypes.comment = "Comment"
