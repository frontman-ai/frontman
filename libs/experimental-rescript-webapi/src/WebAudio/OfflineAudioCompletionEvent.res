include Event.Impl({type t = WebAudioTypes.offlineAudioCompletionEvent})

@new
external make: (
  ~type_: string,
  ~eventInitDict: WebAudioTypes.offlineAudioCompletionEventInit,
) => WebAudioTypes.offlineAudioCompletionEvent = "OfflineAudioCompletionEvent"
