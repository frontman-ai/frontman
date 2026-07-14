/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation)
*/
@new
external make: (
  ~effect: DomTypes.animationEffect=?,
  ~timeline: DomTypes.animationTimeline=?,
) => DomTypes.animation = "Animation"

include EventTarget.Impl({type t = DomTypes.animation})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/cancel)
*/
@send
external cancel: DomTypes.animation => unit = "cancel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/finish)
*/
@send
external finish: DomTypes.animation => unit = "finish"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/play)
*/
@send
external play: DomTypes.animation => unit = "play"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/pause)
*/
@send
external pause: DomTypes.animation => unit = "pause"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/updatePlaybackRate)
*/
@send
external updatePlaybackRate: (DomTypes.animation, float) => unit = "updatePlaybackRate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/reverse)
*/
@send
external reverse: DomTypes.animation => unit = "reverse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/persist)
*/
@send
external persist: DomTypes.animation => unit = "persist"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/commitStyles)
*/
@send
external commitStyles: DomTypes.animation => unit = "commitStyles"
