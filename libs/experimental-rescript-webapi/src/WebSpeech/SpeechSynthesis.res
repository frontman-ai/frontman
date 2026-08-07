include EventTarget.Impl({type t = WebSpeechTypes.speechSynthesis})

@send
external speak: (WebSpeechTypes.speechSynthesis, WebSpeechTypes.speechSynthesisUtterance) => unit =
  "speak"

@send
external cancel: WebSpeechTypes.speechSynthesis => unit = "cancel"

@send
external pause: WebSpeechTypes.speechSynthesis => unit = "pause"

@send
external resume: WebSpeechTypes.speechSynthesis => unit = "resume"

@send
external getVoices: WebSpeechTypes.speechSynthesis => array<WebSpeechTypes.speechSynthesisVoice> =
  "getVoices"
