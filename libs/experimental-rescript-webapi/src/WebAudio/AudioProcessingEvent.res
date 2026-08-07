include Event.Impl({type t = WebAudioTypes.audioProcessingEvent})

@new
external make: (
  ~type_: string,
  ~eventInitDict: WebAudioTypes.audioProcessingEventInit,
) => WebAudioTypes.audioProcessingEvent = "AudioProcessingEvent"
