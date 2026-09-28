include EventTarget.Impl({type t = WebSpeechTypes.speechSynthesisUtterance})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesisUtterance)
*/
@new
external make: (~text: string=?) => WebSpeechTypes.speechSynthesisUtterance =
  "SpeechSynthesisUtterance"
