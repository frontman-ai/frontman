include EventTarget.Impl({type t = WebSpeechTypes.speechSynthesis})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/speak)
*/
@send
external speak: (WebSpeechTypes.speechSynthesis, WebSpeechTypes.speechSynthesisUtterance) => unit =
  "speak"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/cancel)
*/
@send
external cancel: WebSpeechTypes.speechSynthesis => unit = "cancel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/pause)
*/
@send
external pause: WebSpeechTypes.speechSynthesis => unit = "pause"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/resume)
*/
@send
external resume: WebSpeechTypes.speechSynthesis => unit = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/getVoices)
*/
@send
external getVoices: WebSpeechTypes.speechSynthesis => array<WebSpeechTypes.speechSynthesisVoice> =
  "getVoices"
