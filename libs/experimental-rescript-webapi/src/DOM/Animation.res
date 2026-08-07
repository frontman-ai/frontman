@new
external make: (
  ~effect: DomTypes.animationEffect=?,
  ~timeline: DomTypes.animationTimeline=?,
) => DomTypes.animation = "Animation"

include EventTarget.Impl({type t = DomTypes.animation})

@send
external cancel: DomTypes.animation => unit = "cancel"

@send
external finish: DomTypes.animation => unit = "finish"

@send
external play: DomTypes.animation => unit = "play"

@send
external pause: DomTypes.animation => unit = "pause"

@send
external updatePlaybackRate: (DomTypes.animation, float) => unit = "updatePlaybackRate"

@send
external reverse: DomTypes.animation => unit = "reverse"

@send
external persist: DomTypes.animation => unit = "persist"

@send
external commitStyles: DomTypes.animation => unit = "commitStyles"
