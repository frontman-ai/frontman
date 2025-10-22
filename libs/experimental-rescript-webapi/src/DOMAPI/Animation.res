open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation)
*/
@new
external make: (~effect: animationEffect=?, ~timeline: animationTimeline=?) => animation =
  "Animation"

include EventTarget.Impl({type t = animation})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/cancel)
*/
@send
external cancel: animation => unit = "cancel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/finish)
*/
@send
external finish: animation => unit = "finish"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/play)
*/
@send
external play: animation => unit = "play"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/pause)
*/
@send
external pause: animation => unit = "pause"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/updatePlaybackRate)
*/
@send
external updatePlaybackRate: (animation, float) => unit = "updatePlaybackRate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/reverse)
*/
@send
external reverse: animation => unit = "reverse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/persist)
*/
@send
external persist: animation => unit = "persist"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Animation/commitStyles)
*/
@send
external commitStyles: animation => unit = "commitStyles"
