/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DocumentTimeline)
*/
@new
external make: (~options: DomTypes.documentTimelineOptions=?) => DomTypes.documentTimeline =
  "DocumentTimeline"

external asAnimationTimeline: DomTypes.documentTimeline => DomTypes.animationTimeline = "%identity"
