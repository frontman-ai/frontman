include CharacterData.Impl({type t = DomTypes.text})

@new
external make: (~data: string=?) => DomTypes.text = "Text"

@send
external splitText: (DomTypes.text, int) => DomTypes.text = "splitText"
