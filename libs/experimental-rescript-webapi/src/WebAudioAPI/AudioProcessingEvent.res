open WebAudioAPI

include Event.Impl({type t = audioProcessingEvent})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AudioProcessingEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: audioProcessingEventInit) => audioProcessingEvent =
  "AudioProcessingEvent"
