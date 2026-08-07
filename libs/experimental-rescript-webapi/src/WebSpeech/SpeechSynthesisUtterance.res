include EventTarget.Impl({type t = WebSpeechTypes.speechSynthesisUtterance})

@new
external make: (~text: string=?) => WebSpeechTypes.speechSynthesisUtterance =
  "SpeechSynthesisUtterance"
