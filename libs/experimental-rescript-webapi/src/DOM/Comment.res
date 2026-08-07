include CharacterData.Impl({type t = DomTypes.comment})

@new
external make: (~data: string=?) => DomTypes.comment = "Comment"
