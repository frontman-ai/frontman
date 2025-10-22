open WebAudioAPI

include Event.Impl({type t = offlineAudioCompletionEvent})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioCompletionEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: offlineAudioCompletionEventInit,
) => offlineAudioCompletionEvent = "OfflineAudioCompletionEvent"
