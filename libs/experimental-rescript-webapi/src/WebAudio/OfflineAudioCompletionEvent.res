include Event.Impl({type t = WebAudioTypes.offlineAudioCompletionEvent})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OfflineAudioCompletionEvent)
*/
@new
external make: (
  ~type_: string,
  ~eventInitDict: WebAudioTypes.offlineAudioCompletionEventInit,
) => WebAudioTypes.offlineAudioCompletionEvent = "OfflineAudioCompletionEvent"
