open WebSpeechAPI

include EventTarget.Impl({type t = speechSynthesis})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/speak)
*/
@send
external speak: (speechSynthesis, speechSynthesisUtterance) => unit = "speak"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/cancel)
*/
@send
external cancel: speechSynthesis => unit = "cancel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/pause)
*/
@send
external pause: speechSynthesis => unit = "pause"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/resume)
*/
@send
external resume: speechSynthesis => unit = "resume"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/SpeechSynthesis/getVoices)
*/
@send
external getVoices: speechSynthesis => array<speechSynthesisVoice> = "getVoices"
