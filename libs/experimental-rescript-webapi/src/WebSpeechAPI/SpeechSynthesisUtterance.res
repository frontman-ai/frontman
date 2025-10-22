open WebSpeechAPI

include EventTarget.Impl({type t = speechSynthesisUtterance})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesisUtterance)
*/
@new
external make: (~text: string=?) => speechSynthesisUtterance = "SpeechSynthesisUtterance"
