open DOMAPI

include CharacterData.Impl({type t = comment})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Comment)
*/
@new
external make: (~data: string=?) => comment = "Comment"
