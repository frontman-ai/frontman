open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentTimeline)
*/
@new
external make: (~options: documentTimelineOptions=?) => documentTimeline = "DocumentTimeline"

external asAnimationTimeline: documentTimeline => animationTimeline = "%identity"
