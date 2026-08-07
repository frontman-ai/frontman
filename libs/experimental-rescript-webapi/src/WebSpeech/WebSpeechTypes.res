@@warning("-30")

@editor.completeFrom(SpeechSynthesis)
type speechSynthesis = private {
  ...EventTypes.eventTarget,
  pending: bool,
  speaking: bool,
  paused: bool,
}

type speechSynthesisVoice = {
  voiceURI: string,
  name: string,
  lang: string,
  localService: bool,
  default: bool,
}

@editor.completeFrom(SpeechSynthesisUtterance)
type speechSynthesisUtterance = {
  ...EventTypes.eventTarget,
  mutable text: string,
  mutable lang: string,
  mutable voice: Null.t<speechSynthesisVoice>,
  mutable volume: float,
  mutable rate: float,
  mutable pitch: float,
}
